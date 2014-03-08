require 'akabei/error'

module Akabei
  module System
    class CommandFailed < Error
      attr_reader :env, :args, :opts
      def initialize(env, args, opts)
        super("command failed: #{args.join(' ')}")
        @env = env
        @args = args
        @opts = opts
      end
    end

    module_function

    def sudo(args, opts)
      if opts.has_key?(:env)
        opts = opts.dup
        args = args.dup
        env = opts.delete(:env)
        env.each do |k, v|
          args.unshift("#{k}=#{v}")
        end
        args.unshift('env')
      end

      puts "SUDO: #{args.join(' ')}"
      system(%w[sudo] + args, opts)
    end

    def system(args, opts)
      opts = opts.dup
      env = {}
      opts.delete(:env).tap do |e|
        break unless e
        e.each do |k, v|
          env[k.to_s] = v.to_s
        end
      end
      opts.delete(:arch).tap do |a|
        break unless a
        args = args.dup
        args.unshift('setarch', a)
      end

      pid = Kernel.spawn(env, *args.map(&:to_s), opts)
      begin
        _, status = Process.waitpid2(pid)
      rescue SignalException => e
        _, status = Process.waitpid2(pid)
      end
      unless status.success?
        raise CommandFailed.new(env, args, opts)
      end
      status
    end
  end
end
