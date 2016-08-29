require 'spec_helper'
require 'kitchen'
require 'kitchen-salt/util'

describe Kitchen::Salt::Util do
  describe '#unsymbolize' do
    [
      [
        { a: 1 },
        { 'a' => 1 }
      ],
      [
        { a: { b: 1 } },
        { 'a' => { 'b' => 1 } }
      ],
      [
        { a: [{ b: 1 }] },
        { 'a' => [{ 'b' => 1 }] }
      ]
    ].each do |test_case|
      describe test_case[0] do
        let(:klass) { Class.new.extend(Kitchen::Salt::Util) }
        subject { klass.send(:unsymbolize, test_case[0]) }
        it { is_expected.to eq test_case[1] }
      end
    end
  end

  describe '#cp_r_with_filter' do
    let(:klass) { Class.new.extend(Kitchen::Salt::Util) }
    let(:tmpdir_path) { Pathname.new(@tmpdir) }
    let(:tmpdir_files) { Dir[File.join(@tmpdir, '**', '*')] }
    let(:source) { 'spec/fixtures/data-path' }
    let(:filter) { [] }

    around(:each) do |example|
      Dir.mktmpdir do |dir|
        @tmpdir = dir
        example.run
      end
    end

    subject do
      tmpdir_files.collect do |f|
        Pathname.new(f).relative_path_from(tmpdir_path) if File.file?(f)
      end.compact.collect(&:to_s)
    end

    before { allow(klass).to receive(:debug) }
    before { klass.send(:cp_r_with_filter, source, @tmpdir, filter) }

    context 'using filter' do
      let(:source) { 'spec/fixtures/formula-foo' }

      context 'filter a file' do
        let(:filter) { ['FORMULA'] }
        it { is_expected.not_to include 'FORMULA' }
      end

      context 'filter a folder' do
        let(:filter) { ['foo'] }
        it { is_expected.not_to include 'foo/init.sls' }
      end

      context "filter partial path doesn't work" do
        let(:filter) { ['foo/init.sls'] }
        it { is_expected.to include 'foo/init.sls' }
      end
    end

    context 'using source with symlinks' do
      let(:source) { 'spec/fixtures/symlink-test' }

      context 'files' do
        it { is_expected.to include 'top.sls' }
      end

      context 'directories' do
        it { is_expected.to include 'bar/bar.sls' }
      end
    end

    context 'with source string' do
      let(:source) { 'spec/fixtures/data-path' }
      it { is_expected.to contain_exactly 'foo.txt' }
    end

    context 'with source array' do
      let(:source) { ['spec/fixtures/data-path', 'spec/fixtures/formula-foo'] }
      it { is_expected.to include 'foo.txt' }
      it { is_expected.to include 'foo/init.sls' }
    end
  end
end
