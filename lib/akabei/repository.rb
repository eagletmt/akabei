require 'akabei/archive_utils'
require 'akabei/error'
require 'akabei/package_entry'
require 'forwardable'
require 'pathname'
require 'tmpdir'

module Akabei
  class Repository
    def initialize
      @db = {}
    end

    extend Forwardable
    include Enumerable
    def_delegator(:@db, :each)

    def load(path)
      ArchiveUtils.each_entry(path) do |entry, archive|
        pkgname, key = *entry.pathname.split('/', 2)
        if key.include?('/')
          raise Error.new("Malformed repository database: #{path}: #{entry.pathname}")
        end
        @db[pkgname] ||= PackageEntry.new
        case key
        when ''
          # Ignore
        when 'desc', 'depends', 'files'
          load_entries(@db[pkgname], archive.read_data)
        else
          raise Error.new("Unknown repository database key: #{key}")
        end
      end
      nil
    end

    def self.load(path)
      new.tap do |repo|
        repo.load(path)
      end
    end

    def load_entries(entry, data)
      key = nil
      data.each_line do |line|
        line.strip!
        if m = line.match(/\A%([A-Z0-9]+)%\z/)
          key = m[1].downcase
        elsif line.empty?
          key = nil
        else
          entry.add(key, line)
        end
      end
    end

    def add(package)
      @db[package.db_name] = package.to_entry
    end

    def remove(pkgname)
      @db.keys.each do |key|
        if @db[key].name == pkgname
          @db.delete(key)
          return true
        end
      end
      false
    end

    def save(path)
      #XXX: Guess compression and format
      Archive::Writer.open_filename(path, Archive::COMPRESSION_GZIP, Archive::FORMAT_TAR) do |archive|
        Dir.mktmpdir do |dir|
          dir = Pathname.new(dir)
          store_tree(dir)
          create_db(dir, archive)
        end
      end
    end

    def store_tree(topdir)
      @db.each do |db_name, pkg_entry|
        pkgdir = topdir.join(db_name)
        pkgdir.mkpath
        pkgdir.join('desc').open('w') do |f|
          pkg_entry.write_desc(f)
        end
        pkgdir.join('depends').open('w') do |f|
          pkg_entry.write_depends(f)
        end
      end
    end

    def create_db(topdir, archive)
      @db.keys.sort.each do |db_name|
        pkg_entry = @db[db_name]
        archive.new_entry do |entry|
          entry.pathname = "#{db_name}/"
          entry.copy_stat(topdir.join(entry.pathname).to_s)
          archive.write_header(entry)
        end
        %w[desc depends].each do |fname|
          archive.new_entry do |entry|
            entry.pathname = "#{db_name}/#{fname}"
            path = topdir.join(entry.pathname)
            entry.copy_stat(path.to_s)
            archive.write_header(entry)
            archive.write_data(path.read)
          end
        end
      end
    end
  end
end
