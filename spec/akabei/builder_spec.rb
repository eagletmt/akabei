require 'spec_helper'
require 'akabei/builder'
require 'akabei/signer'

describe Akabei::Builder do
  let(:builder) { described_class.new(pkgdest: pkgdest) }
  let(:pkgdest) { test_dest('packages').tap(&:mkpath) }
  let(:package_dir) { test_dest('nkf').tap(&:mkpath) }
  let(:pkgname) { 'nkf-2.1.3-1' }
  let(:arch) { 'x86_64' }
  let(:src_fname) { 'nkf-2.1.3.tar.gz' }
  let(:pkg_fname) { "#{pkgname}-#{arch}.pkg.tar.xz" }
  let(:log_build_fname) { "#{pkgname}-#{arch}-build.log" }
  let(:log_package_fname) { "#{pkgname}-#{arch}-package.log" }
  let(:srcpkg_fname) { "#{pkgname}.src.tar.gz" }

  describe '#build_package' do
    let(:chroot) { double('ChrootTree') }

    before do
      expect(chroot).to receive(:makechrootpkg).once.with(package_dir.to_s, anything) { |dir, env|
        expect(env[:SRCDEST]).to be_directory
        expect(env[:PKGDEST]).to be_directory
        expect(env[:LOGDEST]).to be_directory

        env[:PKGDEST].join(pkg_fname).open('w') {}
        env[:SRCDEST].join(src_fname).open('w') {}
        env[:LOGDEST].join(log_build_fname).open('w') {}
        env[:LOGDEST].join(log_package_fname).open('w') {}
      }
    end

    it 'executes makechrootpkg' do
      packages = builder.build_package(package_dir, chroot)
      expect(packages.size).to eq(1)
      package = packages.first
      expect(package.path).to eq(pkgdest.join(pkg_fname))
      expect(package.path).to be_readable
    end

    context 'with signer' do
      let(:signer) { double('Signer') }

      before do
        builder.signer = signer
      end

      it 'creates a detached signature' do
        expect(signer).to receive(:detach_sign).once { |path|
          File.open("#{path}.sig", 'w') {}
        }

        packages = builder.build_package(package_dir, chroot)
        expect(packages.size).to eq(1)
        package = packages.first
        expect(pkgdest.join("#{pkg_fname}.sig")).to be_readable
      end

      it "doesn't leave packages if signing failed" do
        expect(signer).to receive(:detach_sign).once.and_raise(Akabei::Signer::InvalidSignature.new(double('path'), double('from')))

        expect { builder.build_package(package_dir, chroot) }.to raise_error(Akabei::Signer::InvalidSignature)
        expect(pkgdest.join(pkg_fname)).to_not be_readable
      end
    end

    context 'with srcdest' do
      let(:dest) { test_dest('sources').tap(&:mkpath) }

      before do
        builder.srcdest = dest
      end

      it 'stores sources' do
        builder.build_package(package_dir, chroot)
        expect(dest.join(src_fname)).to be_readable
      end
    end

    context 'with logdest' do
      let(:dest) { test_dest('logs').tap(&:mkpath) }

      before do
        builder.logdest = dest
      end

      it 'stores logs' do
        builder.build_package(package_dir, chroot)
        expect(dest.join(log_build_fname)).to be_readable
        expect(dest.join(log_package_fname)).to be_readable
      end
    end
  end

  describe '#with_source_package' do
    before do
      expect(builder).to receive(:system).once.with(any_args) { |env, makepkg, source, opts|
        srcdest = Pathname.new(env['SRCDEST'])
        srcpkgdest = Pathname.new(env['SRCPKGDEST'])
        builddir = Pathname.new(env['BUILDDIR'])
        expect(srcdest).to be_directory
        expect(srcpkgdest).to be_directory
        expect(builddir).to be_directory

        expect(makepkg).to eq('makepkg')
        expect(source).to eq('--source')
        expect(opts[:chdir]).to eq(package_dir)

        # Simulate `makepkg --source`
        srcdest.join(src_fname).open('w') {}
        srcpkgdest.join(srcpkg_fname).open('w') { |f| f.write('AKABEI SPEC') }
        builddir.join('nkf').mkpath
        Pathname.new(opts[:chdir]).join(srcpkg_fname).make_symlink(srcpkgdest.join(srcpkg_fname))
        true
      }
    end

    it 'creates only source package' do
      builder.with_source_package(package_dir) do |srcpkg|
        expect(srcpkg).to be_readable
        expect(srcpkg.read).to eq('AKABEI SPEC')
      end
    end
  end
end
