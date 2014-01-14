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

    def initialize(chroot_tree)
      @chroot_tree = chroot_tree
    end

    def build(dir)
      Dir.mktmpdir do |tmp_pkgdest|
        tmp_pkgdest = Pathname.new(tmp_pkgdest)
        env = {
          SRCDEST: srcdest.realpath,
          PKGDEST: tmp_pkgdest.realpath,
          LOGDEST: logdest.realpath,
        }
        if @chroot_tree.makechrootpkg(dir.to_s, env)
          tmp_pkgdest.each_child.map do |package_path|
            FileUtils.cp(package_path.to_s, pkgdest.to_s)
            Package.new(pkgdest.join(package_path.basename))
          end
        else
          raise Error.new("makechrootpkg #{dir} failed!")
        end
      end
    end
  end
end
