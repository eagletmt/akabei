require 'spec_helper'
require 'akabei/abs'
require 'akabei/archive_utils'

describe Akabei::Abs do
  let(:repo_name) { 'test' }
  let(:abs_path) { test_dest('abs.tar.gz') }
  let(:abs) { described_class.new(abs_path, repo_name) }

  describe '#add' do
    let(:builder) { double('Builder') }
    let(:dir) { double('dir') }
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

  describe '#remove' do
    context 'without tarbal' do
      it 'raises an error' do
        expect { abs.remove('htop-vi') }.to raise_error(Akabei::Error, /#{Regexp.escape(abs_path.to_s)}/)
      end
    end

    context 'with tarball' do
      before do
        FileUtils.cp(test_input('abs.tar.gz').to_s, abs_path.to_s)
      end

      context 'with valid repository name' do
        it 'removes the package' do
          old_files = Akabei::ArchiveUtils.list_paths(abs_path)
          expect(old_files).to include('test/htop-vi/PKGBUILD')
          abs.remove('htop-vi')
          new_files = Akabei::ArchiveUtils.list_paths(abs_path)
          expect(new_files.to_set).to be_subset(old_files.to_set)
          expect(new_files).to_not include('test/htop-vi/PKGBUILD')
        end

        context 'without the package' do
          it 'does nothing' do
            old_files = Akabei::ArchiveUtils.list_paths(abs_path)
            expect(old_files).to include('test/htop-vi/PKGBUILD')
            abs.remove('nkf')
            new_files = Akabei::ArchiveUtils.list_paths(abs_path)
            expect(new_files).to match_array(old_files)
          end
        end
      end
      context 'with invalid repository name' do
        let(:repo_name) { 'vim-latest' }
        it 'raises an error' do
          expect { abs.remove('htop-vi') }.to raise_error(Akabei::Error, /vim-latest/)
        end
      end
    end
  end
end
