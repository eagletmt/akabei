require 'akabei/error'
require 'akabei/signer'
require 'forwardable'
require 'safe_yaml/load'

module Akabei
  module Omakase
    class Config
      class InvalidConfig < Error
      end

      FILE_NAME = '.akabei.yml'

      def self.load
        config = new
        config.load(FILE_NAME)
        config
      end

      extend Forwardable
      def_delegators :@config, :[], :each
      include Enumerable

      def initialize
        @config = {}
      end

      def load(path)
        @config.merge!(SafeYAML.load_file(path, deserialize_symbols: true))
        true
      rescue Errno::ENOENT
        false
      end

      REQUIRED_ATTRIBUTES = %w[
        name
        package_key
        repo_key
        srcdest
        logdest
        pkgbuild
      ].freeze
      REQUIRED_BUILD_ATTRIBUTES = %w[makepkg pacman]

      def validate!
        REQUIRED_ATTRIBUTES.each do |attr|
          unless @config.has_key?(attr)
            raise InvalidConfig.new("#{attr.inspect} is required")
          end
        end
        unless @config['builds'].is_a?(Hash)
          raise InvalidConfig.new('"builds" must be a Hash')
        end
        @config['builds'].each do |arch, config_file|
          REQUIRED_BUILD_ATTRIBUTES.each do |attr|
            unless config_file.has_key?(attr)
              raise InvalidConfig.new("builds.#{arch}: #{attr.inspect} is required")
            end
          end
        end
        true
      end

      def name
        @config['name']
      end

      def srcdest
        Pathname.new(@config['srcdest'])
      end

      def logdest
        Pathname.new(@config['logdest'])
      end

      def pkgbuild
        Pathname.new(@config['pkgbuild'])
      end

      def package_dir(package_name)
        pkgbuild.join(package_name)
      end

      def package_signer
        Signer.get(@config['package_key'])
      end

      def repo_signer
        Signer.get(@config['repo_key'])
      end

      def builds
        @config['builds']
      end

      def repo_path(arch)
        Pathname.new(@config['name']).join('os', arch)
      end

      def db_path(arch)
        repo_path(arch).join("#{@config['name']}.db")
      end

      def files_path(arch)
        repo_path(arch).join("#{@config['name']}.files")
      end

      def abs_path(arch)
        repo_path(arch).join("#{@config['name']}.abs.tar.gz")
      end
    end
  end
end
