require 'akabei/archive_utils'
require 'akabei/error'
require 'fileutils'
require 'pathname'
require 'tmpdir'

module Akabei
  class Abs
    def initialize(path, repo_name, builder)
      @path = Pathname.new(path)
      @repo_name = repo_name
      @builder = builder
    end

    def add(dir)
      @builder.with_source_package(dir) do |srcpkg|
        Dir.mktmpdir do |tree|
          tree = Pathname.new(tree)
          root = tree.join(@repo_name)
          root.mkpath
          if @path.readable?
            ArchiveUtils.extract_all(@path, root)
          end
          pkgname = detect_pkgname(srcpkg)
          FileUtils.rm_rf(root.join(pkgname).to_s)
          ArchiveUtils.extract_all(srcpkg, root)
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
