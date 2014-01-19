require 'spec_helper'
require 'akabei/chroot_tree'

describe Akabei::ChrootTree do
  let(:arch) { 'x86_64' }
  let(:chroot_root) { Pathname.new('/tmp') }
  let(:chroot) { described_class.new(chroot_root, arch) }

  describe '#with_chroot' do
    let(:action) { double('some action') }

    before do
      expect(action).to receive(:call).once
    end

    context 'without root' do
      let(:chroot_root) { nil }

      it 'creates a temporary chroot' do
        expect(chroot).to receive(:mkarchroot).once
        expect(Dir).to receive(:mktmpdir).once.and_call_original
        expect(Akabei::System).to receive(:sudo).with(['rm', '-rf', anything], anything)

        chroot.with_chroot { action.call }
      end
    end

    context 'with root' do
      it 'uses given root' do
        expect(Dir).to_not receive(:mktmpdir)
        expect(Akabei::System).to receive(:sudo) { |args, opts|
          expect(args[0]).to eq('mkarchroot')
          expect(args[1]).to eq(chroot_root.join('root'))
        }

        chroot.with_chroot { action.call }
      end
    end

    it 'respects makepkg_config' do
      path = Pathname.new('/path/to/makepkg.conf')
      chroot.makepkg_config = path
      expect(Akabei::System).to receive(:sudo) { |args, opts|
        expect(args[0]).to eq('mkarchroot')
        expect(args.each_cons(2)).to include(['-M', path])
      }

      chroot.with_chroot { action.call }
    end

    it 'respects pacman_config' do
      path = Pathname.new('/path/to/pacman.conf')
      chroot.pacman_config = path
      expect(Akabei::System).to receive(:sudo) { |args, opts|
        expect(args[0]).to eq('mkarchroot')
        expect(args.each_cons(2)).to include(['-C', path])
      }

      chroot.with_chroot { action.call }
    end
  end
end
