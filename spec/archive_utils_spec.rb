require 'spec_helper'
require 'akabei/archive_utils'
require 'open3'

describe Akabei::ArchiveUtils do
  let(:archive_path) { test_input('htop-vi.tar.gz') }

  def list_tree(dir)
    Akabei::ArchiveUtils.list_tree_paths(dir).map { |path| path.relative_path_from(dir).to_s }
  end

  describe '.list_paths' do
    it 'acts like tar -t' do
      expect(described_class.list_paths(archive_path)).to match_array(tar('tf', archive_path.to_s))
    end
  end

  describe '.extract_all' do
    let(:dest) { test_dest('got').tap(&:mkpath) }
    let(:tar_dest) { test_dest('expected').tap(&:mkpath) }

    it 'acts like tar -x -C' do
      described_class.extract_all(archive_path, dest)
      tar('xf', archive_path.to_s, '-C', tar_dest.to_s)
      expect(list_tree(dest)).to match_array(list_tree(tar_dest))
    end
  end

  describe '.archive_all' do
    let(:dest) { test_dest('got.tar.gz') }
    let(:tar_dest) { test_dest('expected.tar.gz') }
    let(:src_path) { test_input('htop-vi.tar.gz') }
    let(:tree_path) { test_dest('tree').tap(&:mkpath) }

    before do
      tar('xf', src_path.to_s, '-C', tree_path.to_s)
    end

    it 'acts like tar -c -C' do
      described_class.archive_all(tree_path, dest, Archive::COMPRESSION_GZIP, Archive::FORMAT_TAR)
      tar('cf', tar_dest.to_s, '-C', tree_path.to_s, 'htop-vi')
      expect(tar('tf', dest.to_s)).to match_array(tar('tf', tar_dest.to_s))
    end
  end
end
