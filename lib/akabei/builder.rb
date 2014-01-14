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
        else
          raise Error.new("makechrootpkg #{dir} failed!")
        end
      end
    end
  end
end
