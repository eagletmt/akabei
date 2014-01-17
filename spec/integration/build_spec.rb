require 'spec_helper'

describe 'build subcommand', :archlinux do
  let(:pkg_dir) { test_dest('nkf') }
  let(:repo_dir) { test_dest('repo').tap(&:mkpath) }
  let(:base_command) {
    [
      'build',
      '--repo-name', 'test',
      '--repo-dir', repo_dir.to_s,
      '--arch', 'x86_64',
      '--pacman-config', test_input('pacman.x86_64.conf').to_s,
      '--makepkg-config', test_input('makepkg.x86_64.conf').to_s,
      pkg_dir.to_s,
    ]
  }

  before do
    tar('xf', test_input('nkf.tar.gz').to_s, '-C', pkg_dir.parent.to_s)
  end

  context 'with new repository' do
    it 'creates a new package and repository database with files' do
      expect(akabei(*base_command)).to eq(true)

      db_path = repo_dir.join('test.db')
      expect(db_path).to be_file
      db_files = tar('tf', db_path.to_s)
      expect(db_files).to include('nkf-2.1.3-1/desc')
      expect(db_files).not_to include('nkf-2.1.3-1/files')

      files_path = repo_dir.join('test.files')
      expect(files_path).to be_file
      files_files = tar('tf', files_path.to_s)
      expect(files_files).to include('nkf-2.1.3-1/desc')
      expect(files_files).to include('nkf-2.1.3-1/files')

      pkg_path = repo_dir.join('nkf-2.1.3-1-x86_64.pkg.tar.xz')
      expect(pkg_path).to be_file
      expect(tar('tf', pkg_path.to_s)).to include('usr/bin/nkf')

      abs_path = repo_dir.join('test.abs.tar.gz')
      expect(abs_path).to be_file
      expect(tar('tf', abs_path.to_s)).to include('test/nkf/PKGBUILD')
    end

    context 'with --srcdest' do
      let(:srcdest) { test_dest('sources').tap(&:mkpath) }
      let(:build_command) { base_command + ['--srcdest', srcdest.to_s] }

      it 'stores sources' do
        expect(akabei(*build_command)).to eq(true)
        expect(srcdest.join('nkf-2.1.3.tar.gz')).to be_file
      end
    end

    context 'with --logdest' do
      let(:logdest) { test_dest('logs').tap(&:mkpath) }
      let(:build_command) { base_command + ['--logdest', logdest.to_s] }

      it 'stores logs' do
        expect(akabei(*build_command)).to eq(true)
        expect(logdest.join('nkf-2.1.3-1-x86_64-build.log')).to be_file
        expect(logdest.join('nkf-2.1.3-1-x86_64-package.log')).to be_file
      end
    end
  end

  context 'with existing repository' do
    let(:db_path) { repo_dir.join('test.db') }
    let(:files_path) { repo_dir.join('test.files') }
    let(:abs_path) { repo_dir.join('test.abs.tar.gz') }

    before do
      FileUtils.cp(test_input('test.db'), db_path)
      FileUtils.cp(test_input('test.files'), files_path)
      FileUtils.cp(test_input('abs.tar.gz'), abs_path)
    end

    it 'adds a new package' do
      expect(akabei(*base_command)).to eq(true)

      expect(db_path).to be_file
      db_files = tar('tf', db_path.to_s)
      expect(db_files).to include('htop-vi-1.0.2-4/desc')
      expect(db_files).to include('nkf-2.1.3-1/depends')
      expect(db_files).not_to include('nkf-2.1.3-1/files')

      expect(files_path).to be_file
      files_files = tar('tf', files_path.to_s)
      expect(files_files).to include('htop-vi-1.0.2-4/desc')
      expect(files_files).to include('nkf-2.1.3-1/depends')
      expect(files_files).to include('htop-vi-1.0.2-4/files')
      expect(files_files).to include('nkf-2.1.3-1/files')
      d = test_dest('files-dest').tap(&:mkpath)
      tar('xf', files_path.to_s, '-C', d.to_s)
      expect(d.join('nkf-2.1.3-1', 'files').read).to include('usr/bin/nkf')

      expect(abs_path).to be_file
      abs_files = tar('tf', abs_path.to_s)
      expect(abs_files).to include('test/htop-vi/PKGBUILD')
      expect(abs_files).to include('test/nkf/PKGBUILD')
    end
  end
end
