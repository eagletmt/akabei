require 'pathname'

module Akabei
  class ChrootTree
    def initialize(root, arch)
      @root = Pathname.new(root)
      @arch = arch
    end

    BASE_PACKAGES = %w[base base-devel sudo]

    def create
      mkarchroot(*BASE_PACKAGES)
    end

    def remove
      execute('rm', '-rf', @root.to_s)
    end

    def makechrootpkg(dir, env)
      execute('makechrootpkg', '-cur', @root.to_s, chdir: dir, env: env)
    end

    def mkarchroot(*args)
      execute('mkarchroot', @root.join('root').to_s, *args)
    end

    def arch_nspawn(*args)
      execute('arch-nspawn', @root.join('root').to_s, *args)
    end

    def execute(*args)
      command = args[0]
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

      system('sudo', '-p', "[sudo] akabei requires root to execute #{command}: ", 'setarch', @arch, *args)
    end
  end
end
