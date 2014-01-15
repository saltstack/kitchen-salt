# -*- encoding: utf-8 -*-
#
# Author:: Simon McCartney <simon.mccartney@hp.com>
#
# Copyright (C) 2013, Chris Lundquist, Simon McCartney
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

require 'kitchen/provisioner/base'
require 'yaml'

module Kitchen

  module Provisioner

    # Basic Salt Masterless Provisioner, based on work by
    #
    # @author Chris Lundquist (<chris.ludnquist@github.com>)
    class SaltSolo < Base

      default_config :salt_bootstrap, true
      default_config :salt_bootstrap_url, "http://bootstrap.saltstack.org"
      default_config :salt_bootstrap_options, ""

      default_config :chef_bootstrap_url, "https://www.getchef.com/chef/install.sh"

      default_config :salt_config, "/etc/salt"
      default_config :salt_minion_config, "/etc/salt/minion"
      default_config :salt_file_root, "/srv/salt"
      default_config :salt_pillar_root, "/srv/pillar"
      default_config :salt_state_top, "/srv/salt/top.sls"
      default_config :pillars, {}
      default_config :state_top, {}
      default_config :salt_run_highstate, true

      def install_command
        return unless config[:salt_bootstrap]

        salt_url = config[:salt_bootstrap_url]
        chef_url = config[:chef_bootstrap_url]
        bootstrap_options = config[:salt_bootstrap_options]

        <<-INSTALL
          sh -c '
          #{Util.shell_helpers}

          # install salt, if not already installed
          SALT_CALL=`which salt-call`
          if [ -z "${SALT_CALL}" ]
          then
            do_download #{salt_url} /tmp/bootstrap-salt.sh
            #{sudo('sh')} /tmp/bootstrap-salt.sh #{bootstrap_options}
          fi

          # install chef omnibus so that busser works :(
          # TODO: work out how to install enough ruby
          # and set busser: { :ruby_bindir => '/usr/bin/ruby' } so that we dont need the
          # whole chef client
          if [ ! -d "/opt/chef" ]
          then
            echo "-----> Installing Chef Omnibus"
            do_download #{chef_url} /tmp/install.sh
            #{sudo('sh')} /tmp/install.sh
          fi

          '
        INSTALL
      end

      def create_sandbox
        super
        prepare_data
        prepare_minion
        prepare_state_top
        prepare_pillars
        prepare_formula
      end

      def init_command
        debug("initialising Driver #{self.name}")
        data = File.join(config[:root_path], "data")
        "#{sudo('rm')} -rf #{data} ; mkdir -p #{config[:root_path]}"
      end

      def run_command
        debug("running driver #{self.name}")
        # sudo(File.join(config[:root_path], File.basename(config[:script])))
        debug(diagnose())
        if config[:salt_run_highstate]
          sudo("salt-call --config-dir=#{File.join(config[:root_path], config[:salt_config])} --local state.highstate")
        end
      end

      protected

      def prepare_data
        return unless config[:data_path]

        info("Preparing data")
        debug("Using data from #{config[:data_path]}")

        tmpdata_dir = File.join(sandbox_path, "data")
        FileUtils.mkdir_p(tmpdata_dir)
        FileUtils.cp_r(Dir.glob("#{config[:data_path]}/*"), tmpdata_dir)
      end

      def prepare_minion
        info("Preparing salt-minion")

        minion_config_content = <<-MINION_CONFIG.gsub(/^ {10}/, '')
          state_top: top.sls

          file_client: local

          file_roots:
           base:
             - #{File.join(config[:root_path], config[:salt_file_root])}

          pillar_roots:
           base:
             - #{File.join(config[:root_path], config[:salt_pillar_root])}
        MINION_CONFIG

        # create the temporary path for the salt-minion config file
        debug("sandbox is #{sandbox_path}")
        sandbox_minion_config_path = File.join(sandbox_path, config[:salt_minion_config])

        # create the directory & drop the file in
        FileUtils.mkdir_p(File.dirname(sandbox_minion_config_path))
        File.open(sandbox_minion_config_path, "wb") do |file|
          file.write(minion_config_content)
        end

      end

      def unsymbolize(obj)
        return obj.inject({}){|memo,(k,v)| memo[k.to_s] =  unsymbolize(v); memo} if obj.is_a? Hash
        return obj.inject([]){|memo,v| memo << unsymbolize(v); memo} if obj.is_a? Array
        return obj
      end

      def prepare_state_top
        info("Preparing state_top")

        # we get a hash with all the keys converted to symbols, salt doesn't like this
        # to convert all the keys back to strings again
        state_top_content = unsymbolize(config[:attributes][:state_top]).to_yaml
        # .to_yaml will produce ! '*' for a key, Salt doesn't like this either
        state_top_content.gsub!(/(!\s'\*')/, "'*'")
        sandbox_state_top_path = File.join(sandbox_path, config[:salt_state_top])

        # create the directory & drop the file in
        FileUtils.mkdir_p(File.dirname(sandbox_state_top_path))
        File.open(sandbox_state_top_path, "wb") do |file|
          file.write(state_top_content)
        end
      end

      def prepare_pillars
        info("Preparing pillars into #{config[:salt_pillar_root]}")
        debug("Pillars Hash: #{config[:attributes][:pillars]}")

        return if config[:attributes][:pillars].nil?

        # we get a hash with all the keys converted to symbols, salt doesn't like this
        # to convert all the keys back to strings again
        pillars = unsymbolize(config[:attributes][:pillars])
        debug("unsymbolized pillars hash: #{pillars}")

        # write out each pillar (we get key/contents pairs)
        pillars.each do |key,contents|

          # convert the hash to yaml
          pillar = contents.to_yaml

          # .to_yaml will produce ! '*' for a key, Salt doesn't like this either
          pillar.gsub!(/(!\s'\*')/, "'*'")

          # generate the filename
          sandbox_pillar_path = File.join(sandbox_path, config[:salt_pillar_root], key)

          # create the directory where the pillar file will go
          FileUtils.mkdir_p(File.dirname(sandbox_pillar_path))

          debug("Rendered pillar yaml for #{key}:\n #{pillar}")
          # create the directory & drop the file in
          File.open(sandbox_pillar_path, "wb") do |file|
            file.write(pillar)
          end
        end
      end

      def prepare_formula
        info("Preparing formula")
        debug("Using config #{config}")

        formula_dir = File.join(sandbox_path, config[:salt_file_root], config[:formula])
        FileUtils.mkdir_p(formula_dir)
        FileUtils.cp_r(Dir.glob(File.join(config[:kitchen_root], config[:formula], "*")), formula_dir)

      end
    end
  end
end
