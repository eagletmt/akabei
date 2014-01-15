require 'spec_helper'
require 'akabei/abs'
require 'akabei/archive_utils'

describe Akabei::Abs do
  describe '#add' do
    let(:builder) { double('Builder') }
    let(:dir) { double('dir') }
    let(:abs_path) { test_dest('abs.tar.gz') }
    let(:abs) { described_class.new(abs_path, 'test') }
    let(:srcpkg) { test_input('nkf.tar.gz') }

    before do
      allow(builder).to receive(:with_source_package).and_yield(srcpkg)
    end

    context 'with a new tarball' do
      it 'adds a new source tree' do
        abs.add(dir, builder)
        expect(abs_path).to be_file
        files = Akabei::ArchiveUtils.list_paths(abs_path)
        expect(files).to include('test/nkf/PKGBUILD')
      end
    end

    context 'with an existing tarball' do
      before do
        FileUtils.cp(test_input('abs.tar.gz').to_s, abs_path)
      end

      it 'adds a new source tree' do
        old_files = Akabei::ArchiveUtils.list_paths(abs_path)
        expect(old_files).to_not include('test/nkf/PKGBUILD')
        abs.add(dir, builder)
        new_files = Akabei::ArchiveUtils.list_paths(abs_path)
        expect(new_files.to_set).to be_superset(old_files.to_set)
        expect(new_files).to include('test/nkf/PKGBUILD')
      end

      context 'with an existing package' do
        let(:srcpkg) { test_input('htop-vi.tar.gz') }

        it 'replaces the package' do
          old_files = Akabei::ArchiveUtils.list_paths(abs_path)
          abs.add(dir, builder)
          new_files = Akabei::ArchiveUtils.list_paths(abs_path)
          expect(new_files).to match_array(old_files)
        end
      end
    end
  end
end
