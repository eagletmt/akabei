require 'spec_helper'
require 'akabei/abs'
require 'akabei/cli'
require 'akabei/repository'

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
    let(:init_opts) { {} }

    before do
      cli.invoke(:init, ['test'], init_opts)
      tar('xf', test_input('nkf.tar.gz').to_s, '-C', config.pkgbuild.to_s)
    end

    it 'builds a package and add it to repository' do
      %w[i686 x86_64].each do |arch|
        setup_command_expectations(arch, config.package_dir('nkf'))
      end
      cli.invoke(:build, ['nkf'])
    end

    context 'with --s3' do
      let(:init_opts) { { s3: true } }
      let(:access_key_id) { 'ACCESS/KEY' }
      let(:secret_access_key) { 'SECRET/ACCESS/KEY' }
      let(:bucket_name) { 'test.bucket.name' }
      let(:region) { 'ap-northeast-1' }

      let(:s3_client) { double('S3::Client') }
      let(:write_options) { { storage_class: 'REDUCED_REDUNDANCY' } }

      before do
        c = SafeYAML.load_file('.akabei.yml')
        c['s3']['access_key_id'] = access_key_id
        c['s3']['secret_access_key'] = secret_access_key
        c['s3']['bucket'] = bucket_name
        c['s3']['region'] = region
        c['s3']['write_options'] = write_options
        open('.akabei.yml', 'w') { |f| YAML.dump(c, f) }

        allow(Aws::S3::Client).to receive(:new).and_return(s3_client)
      end

      it 'uploads built packages and update repositories' do
        %w[i686 x86_64].each do |arch|
          setup_command_expectations(arch, config.package_dir('nkf'))
        end

        %w[i686 x86_64].each do |arch|
          %w[test.db test.files test.abs.tar.gz].each do |fname|
            # download and upload
            key = "test/os/#{arch}/#{fname}"
            expect(s3_client).to receive(:get_object).with(hash_including(
              bucket: bucket_name,
              key: key,
            )).once
            expect(s3_client).to receive(:put_object).with(hash_including(
              bucket: bucket_name,
              key: key,
            )).once
          end

          # upload only
          pkg = double("S3::Object built package (#{arch})")
          db_name = "nkf-2.1.3-1-#{arch}.pkg.tar.xz"
          expect(s3_client).to receive(:put_object).with(hash_including(
            write_options.merge(
              bucket: bucket_name,
              key: "test/os/#{arch}/#{db_name}",
            )
          )).once
        end

        cli.invoke(:build, ['nkf'])
      end
    end

    context 'when PACKAGE_NAME is wrong' do
      it 'fails early' do
        expect(Akabei::System).to_not receive(:system)
        expect { cli.invoke(:build, ['wrong']) }.to raise_error(Akabei::Error)
      end
    end
  end

  describe '#remove' do
    let(:config) { Akabei::Omakase::Config.load }

    it 'removes package' do
      cli.invoke(:init, ['test'])
      %w[i686 x86_64].each do |arch|
        config.repo_path(arch).mkpath
        FileUtils.cp(test_input('test.db'), config.db_path(arch))
        FileUtils.cp(test_input('test.files'), config.files_path(arch))
        FileUtils.cp(test_input('abs.tar.gz'), config.abs_path(arch))
      end

      %w[i686 x86_64].each do |arch|
        expect(tar('tf', config.db_path(arch).to_s)).to include('htop-vi-1.0.2-4/desc')
        expect(tar('tf', config.files_path(arch).to_s)).to include('htop-vi-1.0.2-4/files')
        expect(tar('tf', config.abs_path(arch).to_s)).to include('test/htop-vi/PKGBUILD')
      end

      cli.invoke(:remove, ['htop-vi'])

      %w[i686 x86_64].each do |arch|
        expect(tar('tf', config.db_path(arch).to_s)).to_not include('htop-vi-1.0.2-4/desc')
        expect(tar('tf', config.files_path(arch).to_s)).to_not include('htop-vi-1.0.2-4/files')
        expect(tar('tf', config.abs_path(arch).to_s)).to_not include('test/htop-vi/PKGBUILD')
      end
    end
  end
end
