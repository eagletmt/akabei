require 'thor'

module Akabei
  module ThorHandler
    module_function
    def wrap(&block)
      block.call
      0
    rescue Thor::Error => e
      $stderr.puts e.message
      10
    end
  end
end
