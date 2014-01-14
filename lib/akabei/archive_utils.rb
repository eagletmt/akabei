require 'libarchive'

module Akabei
  module ArchiveUtils
    module_function

    def each_entry(path, &block)
      Archive.read_open_filename(path.to_s) do |archive|
        while entry = archive.next_header
          block.call(entry, archive)
        end
      end
    end

    BUFSIZ = 8192

    def extract_all(src, dest)
      each_entry(src) do |entry, archive|
        path = dest.join(entry.pathname)
        path.parent.mkpath
        if entry.regular?
          path.open('wb') do |f|
            archive.read_data do |buf|
              f.write(buf)
            end
          end
        end
      end
    end

    def archive_all(src, dest, comp, format)
      Archive::Writer.open_filename(dest.to_s, comp, format) do |archive|
        list_paths(src).sort.each do |path|
          archive.new_entry do |entry|
            entry.pathname = path.relative_path_from(src).to_s
            is_dir = path.directory?
            if is_dir
              entry.pathname += '/'
            end
            entry.copy_stat(path.to_s)
            archive.write_header(entry)
            unless is_dir
              path.open do |f|
                archive.write_data do
                  f.read(BUFSIZ)
                end
              end
            end
          end
        end
      end
    end

    def list_paths(dir)
      paths = []
      q = dir.each_child.to_a
      until q.empty?
        path = q.shift
        paths << path
        if path.directory?
          q += path.each_child.to_a
        end
      end
      paths
    end
  end
end
