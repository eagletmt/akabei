require 'libarchive'

module Akabei
  module ArchiveUtils
    module_function
    def each_entry(path, &block)
      Archive.read_open_filename(path) do |archive|
        while entry = archive.next_header
          block.call(entry, archive)
        end
      end
    end
  end
end
