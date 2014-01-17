require 'spec_helper'
require 'akabei/repository'
require 'akabei/signer'

describe Akabei::Repository do
  let(:repo) { described_class.new }
  let(:db_path) { test_input('test.db') }

  describe '#load' do
    context 'without database' do
      let(:db_path) { test_dest('repo.db') }

      it 'does nothing' do
        repo.load(db_path)
        expect(repo.count).to eq(0)
      end
    end

    context 'with valid database' do
      it 'loads package entries' do
        repo.load(db_path)
        entry = repo['htop-vi']
        expect(entry).to_not be_nil
        expect(entry.files).to be_empty
      end
    end

    context 'with invalid database' do
      let(:db_path) { test_input('abs.tar.gz') }

      it 'raises an error' do
        expect { repo.load(db_path) }.to raise_error(Akabei::Error)
      end
    end

    context 'with signer' do
      let(:signer) { double('Signer') }
      let(:db_path) { test_dest('test.db') }
      let(:sig_path) { test_dest("test.db.sig") }

      before do
        repo.signer = signer
      end

      it 'skips verification if signature is absent' do
        expect { repo.load(db_path) }.to_not raise_error
      end

      context 'with signature' do
        before do
          FileUtils.cp(test_input('test.db'), db_path)
          sig_path.open('w') {}
        end

        it 'loads package entries if the signature is valid' do
          expect(signer).to receive(:verify!).with(db_path)
          repo.load(db_path)
          expect(repo['htop-vi']).not_to be_nil
        end

        it 'raises an error if the signature is invalid' do
          expect(signer).to receive(:verify!).with(db_path).and_raise(Akabei::Signer::InvalidSignature.new(double('path'), double('from')))
          expect { repo.load(db_path) }.to raise_error(Akabei::Signer::InvalidSignature)
          expect(repo.count).to eq(0)
        end
      end
    end

    context 'with files' do
      let(:db_path) { test_input('test.files') }

      it 'loads package entries with files' do
        repo.load(db_path)
        entry = repo['htop-vi']
        expect(entry.files).to_not be_empty
      end
    end
  end

  describe '#add' do
    it 'adds an entry' do
      package = double('package')
      entry = double('entry')
      allow(package).to receive(:db_name).and_return('nkf-2.1.3-1')
      expect(package).to receive(:to_entry).and_return(entry)
      allow(entry).to receive(:name).and_return('nkf')

      repo.add(package)
      expect(repo['nkf']).to eql(entry)
    end
  end

  describe '#remove' do
    before do
      repo.load(db_path)
    end

    context 'with entry present' do
      it 'removes the package entry' do
        expect { repo.remove('htop-vi') }.to change { repo.count }.by(-1)
      end
    end

    context 'with package absent' do
      it 'does nothing' do
        expect { repo.remove('nkf') }.not_to change { repo.count }
      end
    end
  end

  describe '#save' do
    let(:dest_path) { test_dest('test.db') }

    before do
      repo.load(db_path)
    end

    it 'stores repository database' do
      repo.save(dest_path)
      expect(dest_path).to be_readable
      new_repo = described_class.load(dest_path)
      expect(repo).to eq(new_repo)
    end

    context 'with signer' do
      let(:signer) { double('Signer') }

      before do
        repo.signer = signer
      end

      it 'stores repository database and sign it' do
        expect(signer).to receive(:detach_sign).once.with(dest_path) { |path|
          File.open("#{path}.sig", 'w') {}
        }

        repo.save(dest_path)
        expect(Pathname.new("#{dest_path}.sig")).to be_readable
      end
    end

    context 'with include_files' do
      let(:db_path) { test_input('test.files') }

      before do
        repo.include_files = true
      end

      it 'stores repository database' do
        repo.save(dest_path)
        new_repo = described_class.load(dest_path)
        new_repo.include_files = true
        expect(repo).to eq(new_repo)
      end
    end
  end
end
