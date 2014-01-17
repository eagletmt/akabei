require 'spec_helper'
require 'akabei/package'

describe Akabei::Package do
  let(:package) { described_class.new(pkg_path) }
  let(:pkg_path) { test_input('nkf-2.1.3-1-x86_64.pkg.tar.xz') }

  describe '#pkginfo' do
    it 'returns PackageInfo' do
      pkginfo = package.pkginfo
      expect(package.db_name).to eq('nkf-2.1.3-1')
    end

    context "when pkg_path doesn't exist" do
      let(:pkg_path) { test_dest('does_not_exist.pkg.tar.xz') }

      it 'raises an error' do
        expect { package.pkginfo }.to raise_error(Archive::Error)
      end
    end

    context 'with invalid archive' do
      let(:pkg_path) { test_input('nkf.tar.gz') }

      it 'raises an error' do
        expect { package.pkginfo }.to raise_error(Akabei::Error)
      end
    end
  end

  describe '#to_entry' do
    it 'returns PackageEntry' do
      entry = package.to_entry
      expect(entry.sha256sum).to eq('8543fc47ce33a24bc6c0670b045f4b0381dff1472df895879e9a2cf86835a57b')
      expect(entry.pgpsig).to be_nil
    end

    context 'with detached signature file' do
      let(:pkg_path) { test_dest('nkf.pkg.tar.xz') }
      let(:signature) { 'SOME SIGNATURE' }

      before do
        FileUtils.cp(test_input('nkf-2.1.3-1-x86_64.pkg.tar.xz'), pkg_path)
        File.open("#{pkg_path}.sig", 'w') { |f| f.write(signature) }
      end

      it 'returns PackageEntry with pgpsig' do
        entry = package.to_entry
        expect(entry.sha256sum).to eq('8543fc47ce33a24bc6c0670b045f4b0381dff1472df895879e9a2cf86835a57b')
        expect(entry.pgpsig).to eq(Base64.strict_encode64(signature))
      end
    end
  end
end
