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

      repo = Akabei::Repository.new
      repo.signer = options[:repository_key] && Akabei::Signer.new(options[:repository_key])

      builder = Akabei::Builder.new(chroot)
      builder.signer = options[:package_key] && Akabei::Signer.new(options[:package_key])
      builder.srcdest = options[:srcdest]
      builder.logdest = options[:logdest]

      repo_path = Pathname.new(options[:repository_dir])
      repo_name = options[:repository_name]
      builder.pkgdest = repo_path

      db_path = repo_path.join("#{repo_name}.db")
      files_path = repo_path.join("#{repo_name}.files")
      repo.load(db_path)

      abs = Akabei::Abs.new(repo_path.join("#{repo_name}.abs.tar.gz"), builder)

      chroot.with_chroot do
        packages = builder.build_package(package_dir)
        packages.each do |package|
          repo.add(package)
        end
        abs.add(package_dir)
        repo.save(db_path, false)
        repo.save(files_path, true)
      end
    end
  end
end
