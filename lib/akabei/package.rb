require 'akabei/archive_utils'
require 'akabei/error'
require 'akabei/package_entry'
require 'akabei/package_info'
require 'base64'
require 'digest'

module Akabei
  class Package
    class NotFound < Akabei::Error
      attr_reader :path, :archive

      def initialize(archive, path)
        super("#{path} is not found in #{archive}")
        @path = path
        @archive = archive
      end
    end

    def initialize(path)
      @path = Pathname.new(path)
    end

    def pkginfo
      @pkginfo ||= extract_pkginfo
    end

    def extract_pkginfo
      ArchiveUtils.each_entry(@path.to_s) do |entry, archive|
        if entry.pathname == '.PKGINFO'
          return PackageInfo.parse(archive.read_data)
        end
      end
      raise NotFound.new(@path, '.PKGINFO')
    end

    def db_name
      "#{pkgname}-#{pkgver}"
    end

    def csize
      @path.size
    end

    def isize
      pkginfo.size
    end

    def md5sum
      @md5sum ||= compute_checksum('MD5')
    end

    def sha256sum
      @sha256sum ||= compute_checksum('SHA256')
    end

    def compute_checksum(algo)
      Digest(algo).file(@path).hexdigest
    end

    %w[
      pkgname
      pkgver
      pkgbase
      pkgdesc
      url
      license
      arch
      builddate
      packager
      replaces

      provides
    ].each do |attr|
      define_method(attr) do
        pkginfo.public_send(attr)
      end
    end

    %w[
      group
      depend
      conflict
      optdepend
      makedepend
      checkdepend
    ].each do |attr|
      define_method("#{attr}s") do
        pkginfo.public_send(attr)
      end
    end

    def filename
      @path.basename.to_s
    end

    def name
      pkginfo.pkgname
    end

    def base
      pkginfo.pkgbase
    end

    def version
      pkginfo.pkgver
    end

    def desc
      pkginfo.pkgdesc
    end

    def pgpsig
      sig_file = @path.parent.join("#{filename}.sig")
      if sig_file.readable?
        Base64.strict_encode64(sig_file.binread)
      end
    end

    def files
      xs = []
      ArchiveUtils.each_entry(@path) do |entry|
        unless entry.pathname.start_with?('.')
          xs << entry.pathname
        end
      end
      xs.sort
    end

    def to_entry
      entry = PackageEntry.new
      %w[
        filename
        name
        base
        version
        desc
        groups
        csize
        isize

        md5sum
        sha256sum

        pgpsig

        url
        license
        builddate
        packager
        replaces

        provides
        optdepends
        makedepends
        checkdepends

        files
      ].each do |attr|
        val = send(attr)
        if val.is_a?(Array)
          val.each do |v|
            entry.add(attr, v)
          end
        else
          entry.add(attr, val)
        end
      end
      entry
    end
  end
end
