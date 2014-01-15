require 'pathname'

module Akabei
  module AttrPath
    def attr_path_writer(*attrs)
      attrs.each do |attr|
        define_method("#{attr}=") do |val|
          unless val.nil?
            instance_variable_set("@#{attr}", Pathname.new(val))
          end
        end
      end
    end

    def attr_path_accessor(*attrs)
      attr_reader *attrs
      attr_path_writer *attrs
    end
  end
end
