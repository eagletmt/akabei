require 'akabei/abs'
require 'akabei/builder'
require 'akabei/chroot_tree'
require 'akabei/package'
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
      chroot = ChrootTree.new(options[:chroot_dir], options[:arch])
      if options[:makepkg_config]
        chroot.makepkg_config = options[:makepkg_config]
      end
      if options[:pacman_config]
        chroot.pacman_config = options[:pacman_config]
      end

      repo_db = Repository.new
      repo_db.signer = options[:repository_key] && Signer.new(options[:repository_key])
      repo_files = Repository.new
      repo_files.include_files = true

      builder = Builder.new
      builder.signer = options[:package_key] && Signer.new(options[:package_key])
      builder.srcdest = options[:srcdest]
      builder.logdest = options[:logdest]

      repo_path = Pathname.new(options[:repository_dir])
      repo_name = options[:repository_name]
      builder.pkgdest = repo_path

      db_path = repo_path.join("#{repo_name}.db")
      files_path = repo_path.join("#{repo_name}.files")
      repo_db.load(db_path)
      repo_files.load(files_path)

      abs = Abs.new(repo_path.join("#{repo_name}.abs.tar.gz"), repo_name)

      chroot.with_chroot do
        packages = builder.build_package(package_dir, chroot)
        packages.each do |package|
          repo_db.add(package)
          repo_files.add(package)
        end
        abs.add(package_dir, builder)
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
      builder = Builder.new
      builder.srcdest = options[:srcdest]
      abs = Abs.new(abs_path, options[:repository_name])
      abs.add(package_dir, builder)
    end

    desc 'abs-remove PKG_NAME ABS_TARBALL', 'Remove PKG_NAME from ABS_TARBALL'
    option :repository_name,
      desc: 'Name of the repository',
      banner: 'NAME',
      type: :string,
      required: true
    def abs_remove(package_name, abs_path)
      abs = Abs.new(abs_path, options[:repository_name])
      abs.remove(package_name)
    end

    desc 'repo-add PACKAGE_PATH REPOSITORY_DB', 'Add PACKAGE_PATH to REPOSITORY_DB'
    option :repository_key,
      desc: 'GPG key to sign repository database',
      banner: 'GPGKEY',
      type: :string
    def repo_add(package_path, db_path)
      repo = Repository.new
      repo.signer = options[:repository_key] && Signer.new(options[:repository_key])
      repo.load(db_path)
      repo.add(Package.new(package_path))
      repo.save(db_path)
    end

    desc 'repo-remove PACKAGE_NAME REPOSITORY_DB', 'Remove PACKAGE_NAME from REPOSITORY_DB'
    option :repository_key,
      desc: 'GPG key to sign repository database',
      banner: 'GPGKEY',
      type: :string
    def repo_remove(package_name, db_path)
      repo = Repository.new
      repo.signer = options[:repository_key] && Signer.new(options[:repository_key])
      repo.load(db_path)
      repo.remove(package_name)
      repo.save(db_path)
    end

    desc 'files-add PACKAGE_PATH FILES_DB', 'Add PACKAGE_PATH to FILES_DB'
    def files_add(package_path, db_path)
      repo = Repository.new
      repo.include_files = true
      repo.load(db_path)
      repo.add(Package.new(package_path))
      repo.save(db_path)
    end

    desc 'files-remove PACKAGE_NAME FILES_DB', 'Remove PACKAGE_NAME from FILES_DB'
    def files_remove(package_name, db_path)
      repo = Repository.new
      repo.include_files = true
      repo.load(db_path)
      repo.remove(package_name)
      repo.save(db_path)
    end
  end
end
