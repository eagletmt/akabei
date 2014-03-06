require 'akabei/error'
require 'gpgme'

module Akabei
  class Signer
    class KeyNotFound < Error
      attr_reader :key_name
      def initialize(key_name)
        @key_name = key_name
        super("No such GPG key: #{key_name}")
      end
    end

    class AmbiguousKey < Error
      attr_reader :key_name, :found_keys
      def initialize(key_name, found_keys)
        @key_name = key_name
        @found_keys = found_keys
        super("Ambiguous GPG key: #{key_name}: #{formatted_keys}")
      end

      def formatted_keys
        @found_keys.map do |key|
          subkey = key.primary_subkey
          "#{subkey.length}#{subkey.pubkey_algo_letter}/#{subkey.fingerprint[-8 .. -1]}"
        end
      end
    end

    class InvalidSignature < Error
      attr_reader :path, :from
      def initialize(path, from)
        @path = path
        @from = from
        super("Invalid signature from #{from}: #{path}")
      end
    end

    class AgentNotFound < Error
      def initialize
        super('gpg-agent is not running')
      end
    end

    def self.get(gpg_key, crypto = nil)
      gpg_key && new(gpg_key, crypto)
    end

    def initialize(gpg_key, crypto = nil)
      check_gpg_agent!
      @gpg_key = find_secret_key(gpg_key)
      @crypto = crypto || GPGME::Crypto.new
    end

    def check_gpg_agent!
      if ENV['GPG_AGENT_INFO']
        raise AgentNotFound.new
      end
    end

    def detach_sign(path)
      File.open(path) do |inp|
        File.open("#{path}.sig", 'w') do |out|
          @crypto.detach_sign(inp, signer: @gpg_key, output: out)
        end
      end
    end

    def verify!(path)
      File.open("#{path}.sig") do |sig|
        File.open(path) do |f|
          @crypto.verify(sig, signed_text: f) do |signature|
            unless signature.valid?
              raise InvalidSignature.new(path, signature.from)
            end
          end
        end
      end
    end

    def find_secret_key(key_name)
      keys = GPGME::Key.find(:secret, key_name, :sign)
      if keys.empty?
        raise KeyNotFound.new(key_name)
      elsif keys.size > 1
        raise AmbiguousKey.new(key_name, keys)
      else
        keys.first
      end
    end
  end
end
