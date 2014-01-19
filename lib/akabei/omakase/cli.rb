require 'akabei/build_helper'
require 'akabei/omakase/config'
require 'akabei/omakase/s3'
require 'thor'

module Akabei
  module Omakase
    class CLI < Thor
      namespace :omakase

      include Thor::Actions
      include Thor::Shell
      include BuildHelper

      def self.source_root
        File.expand_path('../templates', __FILE__)
      end

      def self.banner(task, namespace = nil, subcommand = false)
        super(task, nil, true)
      end

      desc 'init NAME', "Generate omakase template for NAME repository"
      option :repo_key,
        desc: 'GPG key to sign repository database',
        banner: 'GPGKEY',
        type: :string
      option :package_key,
        desc: 'GPG key to sign repository database',
        banner: 'GPGKEY',
        type: :string
      option :s3,
        desc: 'Enable S3 repository',
        type: :boolean,
        default: false
      def init(name)
        # Check key's validity
        if options[:repo_key]
          Signer.new(options[:repo_key])
        end
        if options[:package_key]
          Signer.new(options[:package_key])
        end

        if options[:s3]
          begin
            require 'aws-sdk'
          rescue LoadError => e
            say("WARNING: You don't have aws-sdk installed. Disable S3 repository.", :yellow)
            options[:s3] = false
          end
        end

        @name = name
        @archs = %w[i686 x86_64]
        template('.akabei.yml.tt')
        empty_directory(name)
        empty_directory('sources')
        empty_directory('logs')
        empty_directory('PKGBUILDs')
        empty_directory('etc')
        @archs.each do |arch|
          copy_file("makepkg.#{arch}.conf", "etc/makepkg.#{arch}.conf")
          copy_file("pacman.#{arch}.conf", "etc/pacman.#{arch}.conf")
        end

        say('Edit etc/makepkg.*.conf and set PACKAGER first!', :green)
      end

      desc 'build PACKAGE_NAME', "build PACKAGE_NAME"
      def build(package_name)
        builder = Builder.new(
          signer: config.package_signer,
          srcdest: config.srcdest,
          logdest: config.logdest,
        )
        repo_signer = config.repo_signer
        s3 = S3.new(config['s3'], shell)

        config.builds.each do |arch, config_file|
          chroot = ChrootTree.new(nil, arch)
          chroot.makepkg_config = config_file['makepkg']
          chroot.pacman_config = config_file['pacman']

          repo_path = config.repo_path(arch)
          repo_path.mkpath
          builder.pkgdest = repo_path

          db_path = config.db_path(arch)
          files_path = config.files_path(arch)
          abs = Abs.new(config.abs_path(arch), config.name)

          s3.before!(config, arch)
          repo_db = Repository.load(db_path, signer: repo_signer)
          repo_files = Repository.load(files_path, include_files: true)

          packages = build_in_chroot(builder, chroot, repo_db, repo_files, abs, config.package_dir(package_name))
          repo_db.save(db_path)
          repo_files.save(files_path)
          s3.after!(config, arch, packages)
        end
      end

      desc 'remove PACKAGE_NAME', 'remove PACKAGE_NAME'
      def remove(package_name)
        repo_signer = config.repo_signer
        s3 = S3.new(config['s3'], shell)

        config.builds.each do |arch, config_file|
          db_path = config.db_path(arch)
          files_path = config.files_path(arch)
          abs = Abs.new(config.abs_path(arch), config.name)

          s3.before!(config, arch)
          repo_db = Repository.load(db_path, signer: repo_signer)
          repo_files = Repository.load(files_path, include_files: true)

          remove_it(repo_db, package_name)
          remove_it(repo_files, package_name)
          abs.remove(package_name)
          repo_db.save(db_path)
          repo_files.save(files_path)
          s3.after!(config, arch, [])
        end
      end

      private

      def config
        @config ||= begin
          c = Config.load
          c.validate!
          c
        end
      end

      def remove_it(repo, package_name)
        entry = repo.remove(package_name)
        if entry
          say("#{entry.db_name} is removed")
        else
          say("WARNING: #{package_name} doesn't exist", :yellow)
        end
      end
    end
  end
end
