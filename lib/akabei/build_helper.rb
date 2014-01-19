require 'akabei/error'

module Akabei
  module BuildHelper
    def build_in_chroot(builder, chroot, repo_db, repo_files, abs, package_dir)
      unless package_dir.directory?
        raise Error.new("#{package_dir} isn't a directory")
      end
      chroot.with_chroot do
        packages = builder.build_package(package_dir, chroot)
        packages.each do |package|
          repo_db.add(package)
          repo_files.add(package)
        end
        abs.add(package_dir, builder)
        packages
      end
    end
  end
end
