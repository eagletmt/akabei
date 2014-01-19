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
    let(:init_opts) { {} }

    before do
      cli.invoke(:init, ['test'], init_opts)
      tar('xf', test_input('nkf.tar.gz').to_s, '-C', config.pkgbuild.to_s)

      expect(config['builds'].size).to eq(2)

      %w[i686 x86_64].each do |arch|
        expect(Akabei::System).to receive(:sudo).with(array_starting_with(['mkarchroot']), hash_including(arch: arch))
        expect(Akabei::System).to receive(:sudo).with(['rm', '-rf', anything], {})

        expect(Akabei::System).to receive(:sudo).with(['makechrootpkg', '-cur', anything], hash_including(arch: arch, chdir: config.package_dir('nkf').to_s)) { |args, opts|
          FileUtils.cp(test_input('nkf-2.1.3-1-x86_64.pkg.tar.xz'), opts[:env][:PKGDEST].join("nkf-2.1.3-1-#{arch}.pkg.tar.xz"))
        }
        expect(Akabei::System).to receive(:system).with(['makepkg', '--source'], hash_including(chdir: config.package_dir('nkf'))) { |args, opts|
          FileUtils.cp(test_input('nkf.tar.gz'), opts[:env][:SRCPKGDEST])
          Pathname.new(opts[:chdir]).join('nkf.tar.gz').make_symlink(opts[:env][:SRCPKGDEST])
        }
      end
    end

    it 'builds a package and add it to repository' do
      cli.invoke(:build, ['nkf'])
    end

    context 'with --s3' do
      let(:init_opts) { { s3: true } }
      let(:access_key_id) { 'ACCESS/KEY' }
      let(:secret_access_key) { 'SECRET/ACCESS/KEY' }
      let(:bucket_name) { 'test.bucket.name' }
      let(:region) { 'ap-northeast-1' }

      let(:buckets) { double('S3::BucketCollection') }
      let(:bucket) { double('S3::Bucket') }
      let(:objects) { double('S3::ObjectCollection') }
      let(:write_options) { { reduced_redundancy: true } }

      before do
        c = SafeYAML.load_file('.akabei.yml')
        c['s3']['access_key_id'] = access_key_id
        c['s3']['secret_access_key'] = secret_access_key
        c['s3']['bucket'] = bucket_name
        c['s3']['region'] = region
        c['s3']['write_options'] = write_options
        open('.akabei.yml', 'w') { |f| YAML.dump(c, f) }

        allow_any_instance_of(AWS::S3).to receive(:buckets).and_return(buckets)
      end

      it 'uploads built packages and update repositories' do
        expect(buckets).to receive(:[]).with(bucket_name).and_return(bucket)
        allow(bucket).to receive(:objects).and_return(objects)

        %w[i686 x86_64].each do |arch|
          %w[test.db test.files test.abs.tar.gz].each do |fname|
            obj = double("S3::Object #{fname}")
            # download and upload
            expect(objects).to receive(:[]).with("test/os/#{arch}/#{fname}").twice.and_return(obj)
            expect(obj).to receive(:read).and_yield('')
            expect(obj).to receive(:write)
          end

          # upload only
          pkg = double("S3::Object built package (#{arch})")
          db_name = "nkf-2.1.3-1-#{arch}.pkg.tar.xz"
          expect(objects).to receive(:[]).with("test/os/#{arch}/#{db_name}").and_return(pkg)
          expect(pkg).to receive(:write).with(anything, hash_including(write_options))
        end

        cli.invoke(:build, ['nkf'])
      end
    end
  end
end
