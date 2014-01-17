require 'spec_helper'
require 'akabei/package'

describe Akabei::PackageInfo do
  describe '.parse' do
    it 'parses .PKGINFO' do
      pkginfo = described_class.parse(test_input('ruby.PKGINFO').read)
      expect(pkginfo.pkgver).to eq('2.1.0-2')
      expect(pkginfo.pkgbase).to eq('ruby')
      expect(pkginfo.provides).to match_array(%w[rake rubygems])
      expect(pkginfo.group).to eq([])

      pkginfo = described_class.parse(test_input('nkf.PKGINFO').read)
      expect(pkginfo.pkgbase).to be_nil
    end
  end
end
