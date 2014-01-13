require 'akabei/error'

module Akabei
  class PkgInfo
    ARRAY_ATTRIBUTES = %w[
      checkdepend
      conflict
      depend
      group
      license
      makedepend
      makepkgopt
      optdepend
      pkgbase
      provides
      replaces
    ].freeze

    ATTRIBUTES = %w[
      arch
      builddate
      csize
      md5sum
      packager
      pkgdesc
      pkgname
      pkgver
      sha256sum
      size
      url
    ].freeze

    attr_accessor *ARRAY_ATTRIBUTES
    attr_accessor *ATTRIBUTES

    def initialize
      ARRAY_ATTRIBUTES.each do |attr|
        send("#{attr}=", [])
      end
    end

    def self.parse(data)
      info = new
      data.each_line do |line|
        line.strip!
        next if line.start_with?('#')
        if m = line.match(/\A(\w+)\s*=\s*(.+)\z/)
          key = m[1]
          val = m[2]
          if ARRAY_ATTRIBUTES.include?(key)
            info.send(key) << val
          elsif ATTRIBUTES.include?(key)
            if v = info.send(key)
              raise Error.new("Duplicated entry #{key}: #{v} and #{val}")
            else
              info.send("#{key}=", val)
            end
          else
            raise Error.new("Unknown attribute: #{key}: #{val}")
          end
        else
          raise Error.new("Malformed line: #{line}")
        end
      end
      info
    end
  end
end
