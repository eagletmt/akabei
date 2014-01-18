require 'akabei/attr_path'
require 'akabei/error'
require 'pathname'
require 'tmpdir'

module Akabei
  class ChrootTree
    class CommandFailed < Error
      attr_reader :args
      def initialize(args)
        super("command failed: #{args.join(' ')}")
        @args = args
      end
    end

    attr_reader :root, :arch
    extend AttrPath
    attr_path_accessor :makepkg_config, :pacman_config

    def initialize(root, arch)
      @root = root && Pathname.new(root)
      @arch = arch
    end

    BASE_PACKAGES = %w[base base-devel sudo]

    def with_chroot(&block)
      if @root
        mkarchroot(*BASE_PACKAGES)
        block.call
      else
        @root = Pathname.new(Dir.mktmpdir)
        begin
          mkarchroot(*BASE_PACKAGES)
          block.call
        ensure
          execute('rm', '-rf', @root.to_s)
          @root = nil
        end
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
          opts = opts.dup
          env = opts.delete(:env)
          env.each do |k, v|
            args.unshift("#{k}=#{v}")
          end
          args.unshift('env')
          args[-1] = opts
        end
      end

      puts "Execute: #{args.join(' ')}"
      unless system('sudo', 'setarch', @arch, *args)
        raise CommandFailed.new(args)
      end
    end
  end
end
