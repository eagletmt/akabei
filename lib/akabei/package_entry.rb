require 'akabei/error'

module Akabei
  class PackageEntry
    ARRAY_DESC_ATTRIBUTES = %w[
      groups
      license
      replaces
    ].freeze
    DESC_ATTRIBUTES = %w[
      filename
      name
      base
      version
      desc
      csize
      isize
      md5sum
      sha256sum
      pgpsig
      url
      arch
      builddate
      packager
    ].freeze
    ARRAY_DEPENDS_ATTRIBUTES = %w[
      depends
      conflicts
      provides
      optdepends
      makedepends
      checkdepends
    ].freeze
    ARRAY_FILES_ATTRIBUTES = %w[files].freeze

    ARRAY_ATTRIBUTES = (ARRAY_DESC_ATTRIBUTES + ARRAY_DEPENDS_ATTRIBUTES + ARRAY_FILES_ATTRIBUTES).freeze

    attr_reader *ARRAY_ATTRIBUTES
    attr_reader *DESC_ATTRIBUTES

    def initialize
      ARRAY_ATTRIBUTES.each do |key|
        instance_variable_set("@#{key}", [])
      end
    end

    def add(key, val)
      ivar = "@#{key}".intern
      if ARRAY_ATTRIBUTES.include?(key)
        instance_variable_get(ivar) << val
      elsif DESC_ATTRIBUTES.include?(key)
        if v = instance_variable_get(ivar)
          raise Error.new("Multiple entry found: #{v} and #{val}")
        else
          instance_variable_set(ivar, val)
        end
      else
        raise Error.new("Unknown entry key: #{key}")
      end
    end

    def ==(other)
      (ARRAY_ATTRIBUTES + DESC_ATTRIBUTES).all? do |attr|
        public_send(attr) == other.public_send(attr)
      end
    end

    def write_desc(io)
      ARRAY_DESC_ATTRIBUTES.each do |attr|
        write_array(io, attr)
      end

      DESC_ATTRIBUTES.each do |attr|
        write_string(io, attr)
      end
    end

    def write_depends(io)
      ARRAY_DEPENDS_ATTRIBUTES.each do |attr|
        write_array(io, attr)
      end
    end

    def write_files(io)
      ARRAY_FILES_ATTRIBUTES.each do |attr|
        write_array(io, attr)
      end
    end

    def write_array(io, attr)
      arr = instance_variable_get("@#{attr}")
      unless arr.empty?
        write_entry(io, attr, arr)
      end
    end

    def write_string(io, attr)
      if v = instance_variable_get("@#{attr}")
        write_entry(io, attr, v)
      end
    end

    def write_entry(io, attr, val)
      io.puts "%#{attr.upcase}%"
      io.puts val
      io.puts
    end
  end
end
