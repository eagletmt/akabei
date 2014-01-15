require 'akabei/abs'
require 'akabei/builder'
require 'akabei/chroot_tree'
require 'akabei/repository'
require 'akabei/signer'
require 'pathname'
require 'thor'
require 'tmpdir'

module Akabei
  class CLI < Thor
    desc 'build DIR', 'Build package in chroot environment'
    option :chroot_dir,
      desc: 'Path to chroot top',
      banner: 'DIR',
      type: :string
    option :makepkg_config,
      desc: 'Path to makepkg.conf used in chroot',
      banner: 'FILE',
      type: :string
    option :pacman_config,
      desc: 'Path to pacman.conf used in chroot',
      banner: 'FILE',
      type: :string
    option :package_key,
      desc: 'GPG key to sign packages',
      banner: 'GPGKEY',
      type: :string
    option :repository_key,
      desc: 'GPG key to sign repository database',
      banner: 'GPGKEY',
      type: :string
    option :srcdest,
      desc: 'Path to the directory to store sources',
      banner: 'FILE',
      type: :string
    option :logdest,
      desc: 'Path to the directory to store logs',
      banner: 'FILE',
      type: :string
    option :repository_dir,
      desc: 'Path to the repository',
      banner: 'DIR',
      type: :string,
      required: true
    option :repository_name,
      desc: 'Name of the repository',
      banner: 'NAME',
      type: :string,
      required: true
    option :arch,
      desc: 'Archtecture',
      banner: 'ARCH',
      enum: %w[i686 x86_64],
      required: true
    def build(package_dir)
      chroot = Akabei::ChrootTree.new(options[:chroot_dir], options[:arch])
      if options[:makepkg_config]
        chroot.makepkg_config = options[:makepkg_config]
      end
      if options[:pacman_config]
        chroot.pacman_config = options[:pacman_config]
      end

      repo_db = Akabei::Repository.new
      repo_db.signer = options[:repository_key] && Akabei::Signer.new(options[:repository_key])
      repo_files = Akabei::Repository.new
      repo_files.include_files = true

      builder = Akabei::Builder.new
      builder.signer = options[:package_key] && Akabei::Signer.new(options[:package_key])
      builder.srcdest = options[:srcdest]
      builder.logdest = options[:logdest]

      repo_path = Pathname.new(options[:repository_dir])
      repo_name = options[:repository_name]
      builder.pkgdest = repo_path

      db_path = repo_path.join("#{repo_name}.db")
      files_path = repo_path.join("#{repo_name}.files")
      repo_db.load(db_path)
      repo_files.load(files_path)

      abs = Akabei::Abs.new(repo_path.join("#{repo_name}.abs.tar.gz"), repo_name, builder)

      chroot.with_chroot do
        packages = builder.build_package(package_dir, chroot)
        packages.each do |package|
          repo_db.add(package)
          repo_files.add(package)
        end
        abs.add(package_dir)
        repo_db.save(db_path)
        repo_files.save(files_path)
      end
    end

    desc 'abs-add DIR ABS_TARBALL', 'Add the package inside DIR to ABS_TARBALL'
    option :srcdest,
      desc: 'Path to the directory to store sources',
      banner: 'FILE',
      type: :string
    option :repository_name,
      desc: 'Name of the repository',
      banner: 'NAME',
      type: :string,
      required: true
    def abs_add(package_dir, abs_path)
      builder = Akabei::Builder.new
      builder.srcdest = options[:srcdest]
      abs = Akabei::Abs.new(abs_path, options[:repository_name], builder)
      abs.add(package_dir)
    end
  end
end
