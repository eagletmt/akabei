require 'akabei/cli'
require 'akabei/omakase/config'
require 'thor'

module Akabei
  module Omakase
    class CLI < Thor
      namespace :omakase

      include Thor::Actions
      include Thor::Shell

      def self.source_root
        File.expand_path('../templates', __FILE__)
      end

      def self.banner(task, namespace, subcommand)
        super(task, false, true)
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
      def init(name)
        # Check key's validity
        if options[:repo_key]
          Signer.new(options[:repo_key])
        end
        if options[:package_key]
          Signer.new(options[:package_key])
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
        builder = Builder.new
        builder.signer = config['package_key'] && Signer.new(config['package_key'])
        builder.srcdest = config['srcdest']
        builder.logdest = config['logdest']
        repo_signer = config['repo_key'] && Signer.new(config['repo_key'])

        config['builds'].each do |arch, config_file|
          chroot = ChrootTree.new(nil, arch)
          chroot.makepkg_config = config_file['makepkg']
          chroot.pacman_config = config_file['pacman']

          repo_db = Repository.new
          repo_db.signer = repo_signer
          repo_files = Repository.new
          repo_files.include_files = true

          repo_path = Pathname.new(config['name']).join('os', arch)
          repo_path.mkpath
          builder.pkgdest = repo_path

          db_path = repo_path.join("#{config['name']}.db")
          files_path = repo_path.join("#{config['name']}.files")
          repo_db.load(db_path)
          repo_files.load(files_path)
          abs = Abs.new(repo_path.join("#{config['name']}.abs.tar.gz"), config['name'])

          package_dir = Pathname.new(config['pkgbuild']).join(package_name)
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
      end

      private

      def config
        @config ||= begin
          c = Config.load
          c.validate!
          c
        end
      end
    end
  end
end
