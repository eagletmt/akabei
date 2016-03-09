require 'akabei/attr_path'
require 'akabei/error'
require 'akabei/system'
require 'pathname'
require 'tmpdir'

module Akabei
  class ChrootTree
    attr_reader :root, :arch
    extend AttrPath
    attr_path_accessor :makepkg_config, :pacman_config

    def initialize(root, arch)
      @root = root && Pathname.new(root).tap(&:mkpath).realpath
      @arch = arch
    end

    BASE_PACKAGES = %w[base base-devel sudo]

    def with_chroot(&block)
      if @root
        unless @root.join('root').directory?
          mkarchroot(BASE_PACKAGES)
        end
        block.call
      else
        @root = Pathname.new(Dir.mktmpdir)
        begin
          mkarchroot(BASE_PACKAGES)
          block.call
        ensure
          System.sudo(['rm', '-rf', @root], {})
          @root = nil
        end
      end
    end

    def makechrootpkg(dir, env)
      System.sudo(['makechrootpkg', '-cur', @root], chdir: dir, env: env, arch: @arch)
    end

    def mkarchroot(args)
      cmd = ['mkarchroot']
      [['-M', makepkg_config], ['-C', pacman_config]].each do |flag, path|
        if path
          cmd << flag << path
        end
      end
      cmd << @root.join('root')
      System.sudo(cmd + args, arch: @arch)
    end
  end
end
