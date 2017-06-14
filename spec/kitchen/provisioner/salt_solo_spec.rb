# -*- encoding: utf-8 -*-
#
# Author:: Simon McCartney (<simon@mccartney.ie>)
#
# Copyright (C) 2015 Simon McCartney
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require_relative '../../spec_helper'
require 'kitchen'

# Work around for lazy loading
require 'kitchen/provisioner/salt_solo'

describe Kitchen::Provisioner::SaltSolo do
  let(:salt_run_highstate) { true }
  let(:state_top_from_file) { false }
  let(:salt_version) { 'latest' }
  let(:pillars_from_files) { nil }
  let(:is_file_root) { false }
  let(:state_collection) { false }
  let(:data_path) { nil }
  let(:dependencies) { [] }
  let(:pillars) { nil }
  let(:grains) { nil }
  let(:formula) { 'test_formula' }
  let(:vendor_path) { nil }
  let(:salt_copy_filter) { [] }
  let(:local_salt_root) { nil }

  let(:logged_output)   { StringIO.new }
  let(:logger)          { Logger.new(logged_output) }
  let(:platform) do
    instance_double(Kitchen::Platform, os_type: nil)
  end

  let(:config) do
    {
      kitchen_root: @tmpdir,
      formula: formula,
      grains: grains,
      pillars: pillars,
      data_path: data_path,
      dependencies: dependencies,
      state_collection: state_collection,
      state_top_from_file: state_top_from_file,
      :'pillars-from-files' => pillars_from_files,
      vendor_path: vendor_path,
      salt_copy_filter: salt_copy_filter,
      local_salt_root: local_salt_root
    }
  end

  let(:suite) do
    instance_double('Kitchen::Suite', name: 'fries')
  end

  let(:instance) do
    instance_double('Kitchen::Instance',
                    name: 'coolbeans',
                    logger: logger,
                    suite: suite,
                    platform: platform)
  end

  let(:provisioner) do
    Kitchen::Provisioner::SaltSolo.new(config).finalize_config!(instance)
  end

  around(:each) do |example|
    Dir.mktmpdir do |dir|
      @tmpdir = dir
      if not config[:local_salt_root].nil?
        FileUtils.copy_entry(config[:local_salt_root], @tmpdir)
      else
        FileUtils.mkdir(File.join(@tmpdir, 'test_formula'))
      end
      example.run
    end
  end

  describe 'configuration defaults' do
    [
      :pillars_from_files,
      :state_top_from_file,
      :salt_run_highstate,
      :state_collection,
      :data_path,
      :dependencies,
      :pillars,
      :grains,
      :salt_version,
      :vendor_path,
      :salt_copy_filter
    ].each do |opt|
      describe opt do
        subject { provisioner[opt] }
        it { is_expected.to match send(opt) }
      end
    end
  end

  describe '#init_command' do
    subject { provisioner.init_command }

    it 'should give a sane command' do
      is_expected.to match(/mkdir/)
    end
  end

  describe '#run_command' do
    subject { provisioner.run_command }
    let(:config) do
      { salt_version: salt_version }
    end

    context 'without salt version specified' do
      let(:config) do
        {}
      end

      it 'should give a sane run_command' do
        is_expected.to match(/salt-call/)
      end

      it 'should not include extra logic to detect failures' do
        is_expected.not_to match('/tmp/salt-call-output')
      end
    end

    context "with salt version 'latest'" do
      let(:salt_version) { 'latest' }

      it 'should give a sane run_command' do
        is_expected.to match(/salt-call/)
      end

      it 'should not include extra logic to detect failures' do
        is_expected.not_to match('/tmp/salt-call-output')
      end
    end

    context 'with salt version 2016.03.1' do
      let(:salt_version) { '2016.03.1' }

      it 'should give a sane run_command' do
        is_expected.to match(/salt-call/)
      end

      it 'should not include extra logic to detect failures' do
        is_expected.not_to match('/tmp/salt-call-output')
      end
    end

    context 'with salt version 0.17.5' do
      let(:salt_version) { '0.17.5' }

      it 'should give a sane run_command' do
        is_expected.to match(/salt-call/)
      end

      it 'should include extra logic to detect failures' do
        is_expected.to match('/tmp/salt-call-output')
      end
    end

    context 'with log-level' do
      let(:config) do
        { log_level: 'debug' }
      end

      it 'should include log level option' do
        is_expected.to match('--log-level')
      end
    end
  end

  describe '#install_command' do
    subject { provisioner.install_command }

    it 'should include the shell helpers' do
      is_expected.to include Kitchen::Util.shell_helpers.to_s
    end

    it { is_expected.to include 'https://bootstrap.saltstack.org' }

    context 'with salt version 2016.03.1' do
      let(:salt_version) { '2016.03.1' }
      let(:config) do
        { salt_version: salt_version }
      end

      it { is_expected.to include "-P git v#{salt_version}" }
    end
  end

  describe '#create_sandbox' do
    let(:sandbox_path) { Pathname.new(provisioner.sandbox_path) }

    it { expect { provisioner.create_sandbox }.not_to raise_exception }

    context 'with state top from file specified' do
      let(:state_top_from_file) { true }

      around do |example|
        File.open(File.join(@tmpdir, 'top.sls'), 'w') do |f|
          f.write('# test state_top_from_file')
        end
        Dir.pwd.tap do |wd|
          Dir.chdir(@tmpdir)
          example.run
          Dir.chdir(wd)
        end
      end

      it 'should use the file' do
        provisioner.create_sandbox
        top_contents = File.read(File.join(sandbox_path, 'srv/salt/top.sls'))
        expect(top_contents).to match('state_top_from_file')
      end
    end

    describe 'sandbox_path files' do
      let(:sandbox_files) { Dir[File.join(sandbox_path, '**', '*')] }

      subject do
        provisioner.create_sandbox
        sandbox_files.collect do |f|
          Pathname.new(f).relative_path_from(sandbox_path) if File.file?(f)
        end.compact.collect(&:to_s)
      end

      it do
        is_expected.to contain_exactly 'etc/salt/minion', 'srv/salt/top.sls', 'dependencies.sh', 'formula-fetch.sh', 'repository-setup.sh'
      end

      context 'with vendor path' do
        context 'using missing path' do
          let(:vendor_path) { 'path/to/nowhere/that/should/exist' }

          it { expect { subject }.to raise_error(Kitchen::UserError) }
        end

        context 'using absolute path' do
          let(:vendor_path) do
            File.expand_path('./../../../fixtures/vendor-path', __FILE__)
          end

          it { is_expected.to include 'srv/salt/bar/init.sls' }
          it { is_expected.to include 'srv/salt/foo/init.sls' }
        end

        context 'using relative path' do
          let(:vendor_path) { 'spec/fixtures/vendor-path' }

          it { is_expected.to include 'srv/salt/bar/init.sls' }
          it { is_expected.to include 'srv/salt/foo/init.sls' }
        end
      end

      context 'with state collection specified' do
        let(:state_collection) { true }

        before do
          File.open(File.join(@tmpdir, 'test_formula', 'init.sls'), 'w') do |f|
            f.write('# test')
          end
        end

        context 'with collection_name and without formula_name' do
          let(:collection_name) { 'test_formula' }
          let(:formula) { nil }

          it { is_expected.to include 'srv/salt/test_formula/init.sls' }
        end

        context 'without collection_name or formula_name' do
          let(:collection_name) { nil }
          let(:formula) { nil }

          it { is_expected.to include 'srv/salt/test_formula/init.sls' }
        end

        context 'with collection_name and formula_name' do
          let(:collection_name) { 'test_formula' }
          let(:formula) { 'test_formula' }
          let(:fixture_file) { 'srv/salt/test_formula/test_formula/init.sls' }
          it { is_expected.to include fixture_file }
        end

        context 'without collection_name and with formula_name' do
          let(:collection_name) { nil }
          let(:formula) { 'test_formula' }
          let(:fixture_file) { 'srv/salt/test_formula/test_formula/init.sls' }

          it { is_expected.to include fixture_file }
        end
      end

      context 'with grains specified' do
        let(:grains) { { foo: 'bar' } }
        it { is_expected.to include 'etc/salt/grains' }
      end

      context 'local_salt_root transfers pillars and states' do
        let(:config) do
          {
            local_salt_root: 'spec/fixtures/local-salt-root-test',
            formula: nil
          }
        end
        it { is_expected.to include 'srv/pillar/local_salt_root_pillar.sls' }
        it { is_expected.to include 'srv/salt/local_salt_root_test/init.sls'}
      end

      context 'local_salt_root with pillars specified' do
        let(:config) do
          {
            local_salt_root: 'spec/fixtures/local-salt-root-test',
            formula: nil,
            pillars: {
              :'foo.sls' => {foo: 'foo'}
            }
          }
        end
        it { is_expected.to include 'srv/pillar/foo.sls' }
        it { is_expected.not_to include 'srv/pillar/local_salt_root_pillar.sls' }
      end

      context 'local_salt_root with pillars from files specified' do
        let(:config) do
          {
            local_salt_root: 'spec/fixtures/local-salt-root-test',
            formula: nil,
            :'pillars-from-files' => {
              :'test_pillar.sls' => 'spec/fixtures/test_pillar.sls'
            },
            pillars: {
              :'top.sls' => { base: { '*' => ['test_pillar'] } }
            }
          }
        end

        it { is_expected.to include 'srv/pillar/top.sls' }
        it { is_expected.to include 'srv/pillar/test_pillar.sls' }
        it { is_expected.not_to include 'srv/pillar/local_salt_root_pillar.sls' }
      end

      context 'with pillars specified' do
        let(:pillars) do
          {
            :'foo.sls' => { foo: 'foo' },
            :'bar.sls' => { foo: 'bar' }
          }
        end
        it { is_expected.to include 'srv/pillar/foo.sls' }
        it { is_expected.to include 'srv/pillar/bar.sls' }
      end

      context 'with pillars from files' do
        let(:pillars_from_files) do
          {
            :'test_pillar.sls' => 'spec/fixtures/test_pillar.sls'
          }
        end
        let(:pillars) do
          {
            :'top.sls' => { base: { '*' => ['test_pillar'] } }
          }
        end
        it { is_expected.to include 'srv/pillar/top.sls' }
        it { is_expected.to include 'srv/pillar/test_pillar.sls' }
      end

      # FIXME, foo formula dependencies are not passing tests
      #context 'with dependencies' do
      #  let(:dependencies) do
      #    [{
      #      name: 'foo',
      #      path: 'spec/fixtures/formula-foo'
      #    }]
      #  end

      #  it { is_expected.to include 'srv/salt/foo/init.sls' }
      #  it { is_expected.to include 'srv/salt/_states/foo.py' }
      #end

      #context 'with data path' do
      #  let(:data_path) { 'spec/fixtures/data-path' }

      #  it { is_expected.to include 'data/foo.txt' }
      #end
    end
  end
end
