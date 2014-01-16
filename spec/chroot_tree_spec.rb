require 'spec_helper'
require 'akabei/chroot_tree'

describe Akabei::ChrootTree do
  let(:arch) { 'x86_64' }
  let(:chroot_root) { Pathname.new('/tmp') }
  let(:chroot) { described_class.new(chroot_root, arch) }

  describe '#with_chroot' do
    let(:action) { double('some action') }

    before do
      allow(chroot).to receive(:execute) { nil }
      expect(action).to receive(:call).once
    end

    context 'without root' do
      let(:chroot_root) { nil }

      it 'creates a temporary chroot' do
        expect(chroot).to receive(:mkarchroot).once
        expect(Dir).to receive(:mktmpdir).once.and_call_original

        chroot.with_chroot { action.call }
      end
    end

    context 'with root' do
      it 'uses given root' do
        expect(Dir).to_not receive(:mktmpdir)
        expect(chroot).to receive(:execute).once.with(any_args) { |*args|
          expect(args[0]).to eq('mkarchroot')
          expect(args[1]).to eq(chroot_root.join('root').to_s)
        }

        chroot.with_chroot { action.call }
      end
    end

    it 'respects makepkg_config' do
      path = '/path/to/makepkg.conf'
      chroot.makepkg_config = path
      expect(chroot).to receive(:execute).once.with(any_args) { |*args|
        expect(args[0]).to eq('mkarchroot')
        expect(args.each_cons(2)).to include(['-M', path])
      }

      chroot.with_chroot { action.call }
    end

    it 'respects pacman_config' do
      path = '/path/to/pacman.conf'
      chroot.pacman_config = path
      expect(chroot).to receive(:execute).once.with(any_args) { |*args|
        expect(args[0]).to eq('mkarchroot')
        expect(args.each_cons(2)).to include(['-C', path])
      }

      chroot.with_chroot { action.call }
    end
  end

  describe '#execute' do
    let(:command) { %w[rm -rf /] }
    let(:opts) { { chdir: '/' } }

    it 'calls sudo and setarch' do
      expect(chroot).to receive(:system).once.with(any_args) { |*args|
        expect(args).to eq(%W[sudo setarch #{arch}] + command + [opts])
      }

      stdout = capture_stdout do
        chroot.execute(*command + [opts])
      end
      expect(stdout).to include('rm -rf /')
    end

    context 'with :env keyword' do
      let(:key) { :FOO }
      let(:value) { 'BAR' }

      it 'calls sudo, setarch and env' do
        expect(chroot).to receive(:system).once.with(any_args) { |*args|
          expected_opts = opts.dup
          expected_opts.delete(:env)
          expect(args).to eq(%W[sudo setarch #{arch} env #{key}=#{value}] + command + [expected_opts])
        }.and_return(true)

        opts.merge!(env: { key => value })
        stdout = capture_stdout do
          chroot.execute(*command, opts)
        end
        expect(stdout).to include('rm -rf /')
        expect(opts).to have_key(:env)
      end

      context 'with command failure' do
        before do
          allow(chroot).to receive(:system).and_return(false)
        end

        it 'raises an error' do
          expect { capture_stdout { chroot.execute(command + [opts]) } }.to raise_error(Akabei::ChrootTree::CommandFailed)
        end
      end
    end
  end
end
