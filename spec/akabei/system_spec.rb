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
          status = double('Process::Status with failure')
          allow(status).to receive(:success?).and_return(false)
          pid = double('process id')
          allow(Process).to receive(:waitpid2).with(pid).and_return([pid, status])
          allow(Kernel).to receive(:spawn).and_return(pid, status)
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
        expect(Kernel).to receive(:spawn) { |*args|
          args = args.dup
          env = args.shift
          opts = args.pop
          expect(args).to eq(%W[setarch #{arch}] + command)
          expect(opts).to_not have_key(:arch)

          status = double('Process::Status with success')
          allow(status).to receive(:success?).and_return(true)
          pid = double('process id')
          allow(Process).to receive(:waitpid2).with(pid).and_return([pid, status])
          pid
        }

        options.merge!(arch: arch)
        described_class.system(command, options)
        expect(options).to have_key(:arch)
      end

      context 'with command failure' do
        before do
          status = double('Process::Status with failure')
          allow(status).to receive(:success?).and_return(false)
          pid = double('process id')
          allow(Process).to receive(:waitpid2).with(pid).and_return([pid, status])
          allow(Kernel).to receive(:spawn).and_return(pid, status)
        end

        it 'raises an error' do
          expect { described_class.system(command, options) }.to raise_error(Akabei::System::CommandFailed)
        end
      end

      context 'with signal' do
        before do
          status = double('Process::Status with success')
          allow(status).to receive(:success?).and_return(true)
          pid = double('process id')
          allow(Kernel).to receive(:spawn).and_return(pid, status)

          cnt = 0
          allow(Process).to receive(:waitpid2).with(pid) {
            cnt += 1
            case cnt
            when 1
              raise SignalException.new(2)
            when 2
              [pid, status]
            else
              raise 'Process receives waitpid2 too many times'
            end
          }
        end

        it 'raises an error even if the process exit code is 0' do
          expect { described_class.system(command, options) }.to raise_error(Akabei::System::CommandFailed)
        end
      end
    end
  end
end
