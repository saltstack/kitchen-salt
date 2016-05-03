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
require 'ruby-debug'

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
      :formula => "rspec-formula"
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

  describe "#run_command" do
    it "should give a sane run_command" do
      expect(provisioner.run_command).to match(/salt-call/)
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

  describe "#create_sandbox" do
    before do
      @root = Dir.mktmpdir
      config[:kitchen_root] = @root

      create_dummy_formula_under("#{config[:kitchen_root]}/#{config[:formula]}")
      config[:data_path] = "#{config[:kitchen_root]}/my_data"
    end

    after do
      FileUtils.remove_entry(@root)
      begin
        provisioner.cleanup_sandbox
      rescue # rubocop:disable Lint/HandleExceptions
      end
    end

    it "creates a top.sls" do
      provisioner.create_sandbox

      sandbox_oath("top.sls").file?.must_equal true
    end
  end

  def create_dummy_formula_under(path)
    FileUtils.mkdir_p(File.join(path, "sub"))
    File.open(File.join(path, "alpha.txt"), "wb") do |file|
      file.write("stuff")
    end
    File.open(File.join(path, "sub", "bravo.txt"), "wb") do |file|
      file.write("junk")
    end
  end

end
