require 'spec_helper'
require 'akabei/system'

describe Akabei::System do
  let(:command) { %w[rm -rf /] }
  let(:options) { { chdir: '/' } }

  describe '.sudo' do
    it 'executes sudo' do
      expect(Akabei::System).to receive(:system) { |args, opts|
        expect(args).to eq(%w[sudo] + command)
        expect(opts).to eq(options)
      }

      stdout = capture_stdout do
        described_class.sudo(command, options)
      end
      expect(stdout).to include('rm -rf /')
    end

    context 'with :env keyword' do
      let(:key) { :FOO }
      let(:value) { 'BAR' }

      it 'executes sudo and env' do
        expect(Akabei::System).to receive(:system) { |args, opts|
          expect(args).to eq(%W[sudo env #{key}=#{value}] + command)
          expect(opts).to_not have_key(:env)
        }

        options.merge!(env: { key => value })
        stdout = capture_stdout do
          described_class.sudo(command, options)
        end
        expect(stdout).to include('rm -rf /')
        expect(options).to have_key(:env)
      end

      context 'with command failure' do
        before do
          allow(Kernel).to receive(:system).and_return(false)
        end

        it 'raises an error' do
          expect { capture_stdout { described_class.sudo(command, options) } }.to raise_error(Akabei::System::CommandFailed)
        end
      end
    end
  end

  describe '.system' do
    context 'with :arch keyword' do
      let(:arch) { 'armv7h' }

      it 'executes sudo and setarch' do
        expect(Kernel).to receive(:system) { |*args|
          args = args.dup
          env = args.shift
          opts = args.pop
          expect(args).to eq(%W[setarch #{arch}] + command)
          expect(opts).to_not have_key(:arch)
          true
        }

        options.merge!(arch: arch)
        described_class.system(command, options)
        expect(options).to have_key(:arch)
      end

      context 'with command failure' do
        before do
          allow(Kernel).to receive(:system).and_return(false)
        end

        it 'raises an error' do
          expect { described_class.system(command, options) }.to raise_error(Akabei::System::CommandFailed)
        end
      end
    end
  end
end