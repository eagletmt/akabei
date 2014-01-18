require 'spec_helper'
require 'akabei/cli'

class TestShell < Thor::Shell::Basic
  attr_reader :stdout

  def initialize(stdout)
    @stdout = stdout
    super()
  end
end

describe Akabei::Omakase::CLI do
  let(:stdout) { StringIO.new }
  let(:cli) { described_class.new }

  before do
    cli.shell = TestShell.new(stdout)
  end

  around do |example|
    Dir.mktmpdir do |dir|
      cli.inside(dir) do
        Dir.chdir(dir) do
          example.run
        end
      end
    end
  end

  describe '#init' do
    it 'creates template directories' do
      cli.invoke(:init, ['test'])
      here = Pathname.new('.')
      expect(here.join('.akabei.yml')).to be_file
      expect(here.join('test')).to be_directory
      expect(here.join('sources')).to be_directory
      expect(here.join('logs')).to be_directory
      expect(here.join('PKGBUILDs')).to be_directory
      %w[i686 x86_64].each do |arch|
        %w[makepkg pacman].each do |conf|
          expect(here.join('etc', "#{conf}.#{arch}.conf")).to be_file
        end
      end
    end

    it 'creates valid config' do
      cli.invoke(:init, ['test'])
      config = Akabei::Omakase::Config.load
      expect { config.validate! }.to_not raise_error
      expect(config.name).to eq('test')
      expect(config.srcdest).to be_directory
      expect(config.logdest).to be_directory
      expect(config.pkgbuild).to be_directory
      config.builds.each do |arch, config_file|
        expect(Pathname.new(config_file['makepkg'])).to be_file
        expect(Pathname.new(config_file['pacman'])).to be_file
      end
      expect(config['s3']).to be_nil
    end

    context 'with --s3' do
      it 'creates config with s3' do
        cli.invoke(:init, ['test'], s3: true)
        config = Akabei::Omakase::Config.load
        expect { config.validate! }.to_not raise_error
        expect(config['s3']).to_not be_nil
      end
    end
  end

  describe '#build' do
    let(:config) { Akabei::Omakase::Config.load }
    let(:package) { double('built package') }
    let(:entry) { Akabei::PackageEntry.new }
    let(:init_opts) { {} }

    before do
      cli.invoke(:init, ['test'], init_opts)
      tar('xf', test_input('nkf.tar.gz').to_s, '-C', config.pkgbuild.to_s)

      allow(package).to receive(:db_name).and_return('nkf-2.1.3-1')
      allow(package).to receive(:to_entry).and_return(entry)
      entry.add('files', 'usr/bin/nkf')
    end

    it 'builds a package and add it to repository' do
      allow_any_instance_of(Akabei::ChrootTree).to receive(:with_chroot) { |chroot, &block|
        expect(chroot.makepkg_config.to_s).to eq("etc/makepkg.#{chroot.arch}.conf")
        expect(chroot.pacman_config.to_s).to eq("etc/pacman.#{chroot.arch}.conf")
        block.call
      }
      expect(config['builds'].size).to eq(2)
      expect_any_instance_of(Akabei::Builder).to receive(:build_package).twice { |builder, dir, chroot|
        expect(builder).to receive(:with_source_package).with(config.package_dir('nkf')).and_yield(test_input('nkf.tar.gz'))
        [package]
      }

      cli.invoke(:build, ['nkf'])
    end
  end
end
