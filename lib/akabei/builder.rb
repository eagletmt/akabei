require 'akabei/error'
require 'akabei/package'
require 'fileutils'
require 'tmpdir'

module Akabei
  class Builder
    [:srcdest, :pkgdest, :logdest].each do |attr|
      attr_reader attr
      define_method("#{attr}=") do |val|
        instance_variable_set("@#{attr}", Pathname.new(val))
      end
    end
    attr_accessor :signer

    def initialize(chroot_tree)
      @chroot_tree = chroot_tree
    end

    def build_package(dir)
      Dir.mktmpdir do |tmp_pkgdest|
        tmp_pkgdest = Pathname.new(tmp_pkgdest)
        env = {
          SRCDEST: srcdest.realpath,
          PKGDEST: tmp_pkgdest.realpath,
          LOGDEST: logdest.realpath,
        }
        @chroot_tree.makechrootpkg(dir.to_s, env)
        tmp_pkgdest.each_child.map do |package_path|
          begin
            dest = pkgdest.join(package_path.basename)
            FileUtils.cp(package_path.to_s, dest.to_s)
            if signer
              signer.detach_sign(dest)
            end
            Package.new(dest)
          rescue => e
            begin
              dest.unlink
            rescue Errno::ENOENT
            end
            raise e
          end
        end
      end
    end

    def with_source_package(dir, &block)
      dir = Pathname.new(dir)
      Dir.mktmpdir do |tmp_srcpkgdest|
        tmp_srcpkgdest = Pathname.new(tmp_srcpkgdest)
        Dir.mktmpdir do |builddir|
          builddir = Pathname.new(builddir)
          env = {
            'SRCDEST' => srcdest.realpath.to_s,
            'SRCPKGDEST' => tmp_srcpkgdest.realpath.to_s,
            'BUILDDIR' => builddir.realpath.to_s,
          }
          unless system(env, 'makepkg', '--source', chdir: dir)
            raise Error.new("makepkg --source failed: #{dir}")
          end
        end
        children = tmp_srcpkgdest.each_child.to_a
        if children.empty?
          raise Error.new("makepkg --source generated nothing: #{dir}")
        elsif children.size > 1
          raise Error.new("makepkg --source generated multiple files???: #{dir}: #{children.map(&:to_s)}")
        else
          srcpkg = children.first
          # Remove symlink created by makepkg
          dir.join(srcpkg.basename).unlink
          block.call(srcpkg)
        end
      end
    end
  end
end
