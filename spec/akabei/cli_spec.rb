require 'spec_helper'
require 'akabei/cli'

describe Akabei::CLI do
  let(:cli) { described_class.new }
  let(:package_dir) { test_dest('nkf') }
  let(:srcpkg_path) { test_input('nkf.tar.gz') }
  let(:package_path) { test_input('nkf-2.1.3-1-x86_64.pkg.tar.xz') }

  describe '#build' do
    let(:repo_dir) { test_dest('repo').tap(&:mkpath) }
    let(:base_opts) { { arch: 'x86_64', repo_dir:  repo_dir.to_s, repo_name: 'test' } }
    let(:package) { double('built package') }
    let(:entry) { Akabei::PackageEntry.new }
    let(:chroot_expectations) { lambda { |chroot| } }

    before do
      tar('xf', test_input('nkf.tar.gz').to_s, '-C', package_dir.parent.to_s)
      # Disable warning
      entry.add('files', 'usr/bin/nkf')

      allow(package).to receive(:name).and_return('nkf')
      allow(package).to receive(:to_entry).and_return(entry)

      allow_any_instance_of(Akabei::ChrootTree).to receive(:with_chroot) { |chroot, &block|
        chroot_expectations.call(chroot)
        block.call
      }
      allow_any_instance_of(Akabei::Builder).to receive(:build_package) { |builder, dir, chroot|
        expect(builder).to receive(:with_source_package).with(package_dir.to_s).and_yield(srcpkg_path)
        [package]
      }
    end

    it 'calls Builder#build_package in chroot and create repository database' do
      cli.invoke(:build, [package_dir.to_s], base_opts)
      expect(repo_dir.join('test.db')).to be_file
      expect(repo_dir.join('test.files')).to be_file
      expect(repo_dir.join('test.abs.tar.gz')).to be_file
    end

    context 'with --makepkg-config' do
      let(:makepkg_path) { test_input('makepkg.x86_64.conf') }
      let(:chroot_expectations) {
        lambda do |chroot|
          expect(chroot.makepkg_config).to eq(makepkg_path)
        end
      }

      it 'calls ChrootTree#with_chroot with makepkg_config' do
        cli.invoke(:build, [package_dir.to_s], base_opts.merge(makepkg_config: makepkg_path.to_s))
      end
    end

    context 'with --pacman-config' do
      let(:pacman_path) { test_input('pacman.x86_64.conf') }
      let(:chroot_expectations) {
        lambda do |chroot|
          expect(chroot.pacman_config).to eq(pacman_path)
        end
      }

      it 'calls ChrootTree#with_chroot with pacman_config' do
        cli.invoke(:build, [package_dir.to_s], base_opts.merge(pacman_config: pacman_path.to_s))
      end
    end
  end

  describe '#abs_add' do
    let(:repo_name) { 'test' }
    let(:abs_path) { test_dest('abs.tar.gz') }

    it 'creates abs tarball' do
      allow_any_instance_of(Akabei::Builder).to receive(:with_source_package).with(package_dir.to_s).and_yield(srcpkg_path)
      cli.invoke(:abs_add, [package_dir.to_s, abs_path.to_s], repo_name: repo_name)
      expect(abs_path).to be_file
    end
  end

  describe '#abs_remove' do
    let(:repo_name) { 'test' }
    let(:abs_path) { test_dest('abs.tar.gz') }

    before do
      FileUtils.cp(test_input('abs.tar.gz'), abs_path)
    end

    it 'removes package from abs tarball' do
      cli.invoke(:abs_remove, ['htop-vi', abs_path.to_s], repo_name: repo_name)
      expect(abs_path).to be_file
      expect(tar('tf', abs_path.to_s)).to_not include('test/htop-vi/PKGBUILD')
    end
  end

  describe '#repo_add' do
    let(:db_path) { test_dest('test.db') }

    it 'creates repository database' do
      cli.invoke(:repo_add, [package_path.to_s, db_path.to_s])
      expect(db_path).to be_file
      expect(tar('tf', db_path.to_s)).to include('nkf-2.1.3-1/desc')
    end
  end

  describe '#repo_remove' do
    let(:db_path) { test_dest('test.db') }

    before do
      FileUtils.cp(test_input('test.db'), db_path)
    end

    it 'removes package from repository database' do
      cli.invoke(:repo_remove, ['htop-vi', db_path.to_s])
      expect(tar('tf', db_path.to_s)).to_not include('htop-vi-1.0.2-4/desc')
    end
  end

  describe '#files_add' do
    let(:files_path) { test_dest('test.files') }

    it 'creates files database' do
      cli.invoke(:files_add, [package_path.to_s, files_path.to_s])
      expect(files_path).to be_file
      expect(tar('tf', files_path.to_s)).to include('nkf-2.1.3-1/files')
    end
  end

  describe '#files_remove' do
    let(:files_path) { test_dest('test.files') }

    before do
      FileUtils.cp(test_input('test.files'), files_path)
    end

    it 'removes package from files database' do
      cli.invoke(:files_remove, ['htop-vi', files_path.to_s])
      expect(tar('tf', files_path.to_s)).to_not include('htop-vi-1.0.2-4/files')
    end
  end
end
