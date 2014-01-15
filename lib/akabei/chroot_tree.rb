require 'akabei/attr_path'
require 'akabei/error'
require 'pathname'

module Akabei
  class ChrootTree
    class CommandFailed < Error
      attr_reader :args
      def initialize(args)
        super("command failed: #{args.join(' ')}")
        @args = args
      end
    end

    extend AttrPath
    attr_path_accessor :makepkg_config, :pacman_config

    def initialize(root, arch)
      @root = Pathname.new(root)
      @arch = arch
    end

    BASE_PACKAGES = %w[base base-devel sudo]

    def create
      @root.mkpath
      mkarchroot(*BASE_PACKAGES)
    end

    def remove
      if @root.directory?
        execute('rm', '-rf', @root.to_s)
      end
    end

    def makechrootpkg(dir, env)
      execute('makechrootpkg', '-cur', @root.to_s, chdir: dir, env: env)
    end

    def mkarchroot(*args)
      cmd = ['mkarchroot']
      [['-M', makepkg_config], ['-C', pacman_config]].each do |flag, path|
        if path
          cmd << flag << path.to_s
        end
      end
      cmd << @root.join('root').to_s
      execute(*(cmd + args))
    end

    def arch_nspawn(*args)
      execute('arch-nspawn', @root.join('root').to_s, *args)
    end

    def execute(*args)
      if args.last.is_a?(Hash)
        opts = args.last
        if opts.has_key?(:env)
          env = opts.delete(:env)
          env.each do |k, v|
            args.unshift("#{k}=#{v}")
          end
          args.unshift('env')
        end
      end

      puts "Execute: #{args.join(' ')}"
      unless system('sudo', 'setarch', @arch, *args)
        raise CommandFailed.new(args)
      end
    end
  end
end
