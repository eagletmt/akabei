require 'akabei/archive_utils'
require 'akabei/error'
require 'akabei/package_entry'
require 'forwardable'
require 'pathname'
require 'tmpdir'

module Akabei
  class Repository
    attr_accessor :signer, :include_files

    def initialize(opts = {})
      @db = {}
      @include_files = opts[:include_files] || false
      @signer = opts[:signer]
    end

    extend Forwardable
    include Enumerable
    def_delegator(:@db, :each)

    def [](package_name)
      @db.each do |_, entry|
        if entry.name == package_name
          return entry
        end
      end
    end

    def ==(other)
      other.is_a?(self.class) &&
        signer == other.signer &&
        include_files == other.include_files &&
        @db == other.instance_variable_get(:@db)
    end

    def load(path)
      path = Pathname.new(path)
      return unless path.readable?
      verify!(path)
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

    def self.load(path, opts = {})
      new(opts).tap do |repo|
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

    def verify!(path)
      if signer && File.readable?("#{path}.sig")
        signer.verify!(path)
        true
      else
        false
      end
    end

    def save(path)
      Archive::Writer.open_filename(path.to_s, Archive::COMPRESSION_GZIP, Archive::FORMAT_TAR) do |archive|
        Dir.mktmpdir do |dir|
          dir = Pathname.new(dir)
          store_tree(dir)
          create_db(dir, archive)
        end
      end
      if signer
        signer.detach_sign(path)
      end
      nil
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
        if @include_files
          pkgdir.join('files').open('w') do |f|
            pkg_entry.write_files(f)
          end
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
        %w[desc depends files].each do |fname|
          pathname = "#{db_name}/#{fname}"
          path = topdir.join(pathname)
          if path.readable?
            archive.new_entry do |entry|
              entry.pathname = pathname
              entry.copy_stat(path.to_s)
              archive.write_header(entry)
              archive.write_data(path.read)
            end
          end
        end
      end
    end
  end
end
