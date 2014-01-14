require 'akabei/archive_utils'
require 'akabei/error'
require 'fileutils'
require 'pathname'
require 'tmpdir'

module Akabei
  class Abs
    def initialize(path, builder)
      @path = Pathname.new(path)
      @builder = builder
    end

    def add(dir)
      @builder.with_source_package(dir) do |srcpkg|
        Dir.mktmpdir do |tree|
          tree = Pathname.new(tree)
          if @path.readable?
            ArchiveUtils.extract_all(@path, tree)
          end
          pkgname = detect_pkgname(srcpkg)
          FileUtils.rm_rf(tree.join(pkgname).to_s)
          ArchiveUtils.extract_all(srcpkg, tree)
          FileUtils.rm_f(@path.to_s)
          ArchiveUtils.archive_all(tree, @path, Archive::COMPRESSION_GZIP, Archive::FORMAT_TAR)
        end
      end
    end

    def detect_pkgname(srcpkg)
      ArchiveUtils.each_entry(srcpkg) do |entry|
        if entry.directory?
          if m = entry.pathname.match(%r{\A([^/]+)/\z})
            return m[1]
          end
        end
      end
      raise Error.new("Cannot detect pkgname from #{srcpkg}")
    end
  end
end
