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

  let(:logged_output)   { StringIO.new }
  let(:logger)          { Logger.new(logged_output) }
  let(:platform) do
    platform = instance_double(Kitchen::Platform, :os_type => nil)
  end

  let(:config) do
    {
      # TODO
    }
  end

  let(:suite) do
    instance_double("Kitchen::Suite", :name => "fries")
  end

  let(:instance) do
    instance_double("Kitchen::Instance",
      :name => "coolbeans",
      :logger => logger,
      :suite => suite,
      :platform => platform)
  end

  let(:provisioner) do
    Kitchen::Provisioner::SaltSolo.new(config).finalize_config!(instance)
  end

  describe "#init_command" do
    subject { provisioner.init_command }

    it "should give a sane command" do
      is_expected.to match(/mkdir/)
    end
  end

  describe "#run_command" do
    subject { provisioner.run_command }
    let(:config) do
      { salt_version: salt_version }
    end

    context "without salt version specified" do
      let(:config) do
        {}
      end

      it "should give a sane run_command" do
        is_expected.to match(/salt-call/)
      end

      it "should not include extra logic to detect failures" do
        is_expected.not_to match("/tmp/salt-call-output")
      end
    end

    context "with salt version 'latest'" do
      let(:salt_version) { 'latest' }

      it "should give a sane run_command" do
        is_expected.to match(/salt-call/)
      end

      it "should not include extra logic to detect failures" do
        is_expected.not_to match("/tmp/salt-call-output")
      end
    end

    context "with salt version 2016.03.1" do
      let(:salt_version) { '2016.03.1' }

      it "should give a sane run_command" do
        is_expected.to match(/salt-call/)
      end

      it "should not include extra logic to detect failures" do
        is_expected.not_to match("/tmp/salt-call-output")
      end
    end

    context "with salt version 0.17.5" do
      let(:salt_version) { '0.17.5' }

      it "should give a sane run_command" do
        is_expected.to match(/salt-call/)
      end

      it "should include extra logic to detect failures" do
        is_expected.to match("/tmp/salt-call-output")
      end
    end

    context "with log-level" do
      let(:config) do
        { log_level: 'debug' }
      end

      it "should include log level option" do
        is_expected.to match("--log-level")
      end
    end
  end

  describe "#install_command" do
    subject { provisioner.install_command }

    it 'should include the shell helpers' do
      is_expected.to match Kitchen::Util.shell_helpers
    end

    it { is_expected.to match "http://bootstrap.saltstack.org" }

    context "with salt version 2016.03.1" do
      let(:salt_version) { '2016.03.1' }
      let(:config) do
        { salt_version: salt_version }
      end

      it { is_expected.to match "-P git v#{salt_version}" }
    end
  end

  describe "#create_sandbox" do
    let(:grains) { nil }
    let(:pillars) { {} }
    let(:pillars_from_files) { nil }
    let(:dependencies) { [] }
    let(:config) do
      {
        kitchen_root: @tmpdir,
        formula: "test_formula",
        grains: grains,
        pillars: pillars,
        dependencies: dependencies,
        :'pillars-from-files' => pillars_from_files
      }
    end

    around(:each) do |example|
      Dir.mktmpdir do |dir|
        @tmpdir = dir
        FileUtils.mkdir(File.join(@tmpdir, "test_formula"))
        example.run
      end
    end

    it { expect { provisioner.create_sandbox }.not_to raise_exception }

    describe 'sandbox_path files' do
      before { provisioner.create_sandbox }

      let(:sandbox_path) { Pathname.new(provisioner.sandbox_path) }
      let(:sandbox_files) { Dir[File.join(sandbox_path, "**", "*")] }

      subject do
        sandbox_files.collect do |f|
          if File.file?(f)
            Pathname.new(f).relative_path_from(sandbox_path)
          end
        end.compact.collect(&:to_s)
      end

      it { is_expected.to contain_exactly 'etc/salt/minion', 'srv/salt/top.sls' }

      context 'with grains specified' do
        let(:grains) { { foo: 'bar' } }
        it { is_expected.to include 'etc/salt/grains' }
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
        it { is_expected.to include 'srv/pillar/test_pillar.sls' }
      end

      context 'with dependencies' do
        let(:dependencies) do
          [{
            name: 'foo',
            path: 'spec/fixtures/formula-foo'
          }]
        end

        it { is_expected.to include 'srv/salt/foo/init.sls' }
        it { is_expected.to include 'srv/salt/_states/foo.py' }
      end
    end
  end

  describe "configuration" do

    it "should default to salt-formula mode (state_collection=false)" do
      expect(provisioner[:state_collection]).to eq false
    end

    it "should use the .kitchen.yml embedded top.sls" do
      expect(provisioner[:state_top_from_file]).to eq false
    end

    it "should highstate by default" do
      expect(provisioner[:salt_run_highstate]).to eq true
    end
  end
end
