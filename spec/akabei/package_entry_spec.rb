require 'spec_helper'
require 'akabei/package_entry'

describe Akabei::PackageEntry do
  let(:entry) { described_class.new }

  describe '#write_desc' do
    it 'writes desc attributes' do
      entry.add('name', 'akabei')
      entry.add('desc', 'Custom repository manager for ArchLinux pacman')
      entry.add('depends', 'ruby')

      io = StringIO.new
      entry.write_desc(io)
      expect(io.string).to include('akabei')
      expect(io.string).to include('pacman')
      expect(io.string).to_not include('ruby')
    end

    it 'rejects multiple descs' do
      entry.add('desc', 'Custom repository manager for ArchLinux pacman')
      expect { entry.add('desc', 'Awful repository manager') }.to raise_error(Akabei::Error)
      expect(entry.desc).not_to include('Awful')
    end

    it 'rejects unknown attribute' do
      expect { entry.add('akabei', 'akabei') }.to raise_error(Akabei::Error)
    end
  end

  describe '#write_depends' do
    it 'writes depends attributes' do
      entry.add('name', 'akabei')
      entry.add('depends', 'ruby')
      entry.add('makedepends', 'gcc')
      entry.add('makedepends', 'rubygems')

      io = StringIO.new
      entry.write_depends(io)
      expect(io.string).not_to include('akabei')
      expect(io.string).to include('ruby')
      expect(io.string).to include('gcc')
      expect(io.string).to include('rubygems')
    end
  end

  describe '#write_files' do
    it 'writes files attribute' do
      entry.add('name', 'gcc')
      entry.add('files', '/usr/bin/gcov')
      entry.add('files', '/usr/bin/g++')

      io = StringIO.new
      entry.write_files(io)
      expect(io.string).to_not include('gcc')
      expect(io.string).to include('gcov')
      expect(io.string).to include('g++')
    end

    it 'warns if files is empty' do
      entry.add('name', 'gcc')
      entry.add('depends', 'glibc')

      io = StringIO.new
      stderr = capture_stderr { entry.write_files(io) }
      expect(io.string).to be_empty
      expect(stderr).to include('empty')
    end
  end
end
