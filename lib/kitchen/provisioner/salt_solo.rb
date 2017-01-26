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
require 'kitchen-salt/util'
require 'kitchen-salt/pillars'
require 'kitchen-salt/states'
require 'fileutils'
require 'yaml'

module Kitchen
  module Provisioner
    # Basic Salt Masterless Provisioner, based on work by
    #
    # @author Chris Lundquist (<chris.ludnquist@github.com>)

    class SaltSolo < Base
      include Kitchen::Salt::Util
      include Kitchen::Salt::Pillars
      include Kitchen::Salt::States

      DEFAULT_CONFIG = {
        dry_run: false,
        salt_version: 'latest',
        salt_install: 'bootstrap',
        salt_bootstrap_url: 'http://bootstrap.saltstack.org',
        salt_bootstrap_options: '',
        salt_apt_repo: 'http://apt.mccartney.ie',
        salt_apt_repo_key: 'http://apt.mccartney.ie/KEY',
        salt_ppa: 'ppa:saltstack/salt',
        chef_bootstrap_url: 'https://www.getchef.com/chef/install.sh',
        salt_config: '/etc/salt',
        salt_minion_config: '/etc/salt/minion',
        salt_minion_id: nil,
        salt_env: 'base',
        salt_file_root: '/srv/salt',
        salt_pillar_root: '/srv/pillar',
        salt_state_top: '/srv/salt/top.sls',
        state_collection: false,
        state_top: {},
        state_top_from_file: false,
        salt_run_highstate: true,
        salt_copy_filter: [],
        is_file_root: false,
        require_chef: true,
        dependencies: [],
        vendor_path: nil,
        omnibus_cachier: false
      }

      # salt-call version that supports the undocumented --retcode-passthrough command
      RETCODE_VERSION = '0.17.5'.freeze

      DEFAULT_CONFIG.each do |k, v|
        default_config k, v
      end

      def install_command
        debug(diagnose)
        salt_version = config[:salt_version]

        # if salt_verison is set, bootstrap is being used & bootstrap_options is empty,
        # set the bootstrap_options string to git install the requested version
        if (salt_version != 'latest') && (config[:salt_install] == 'bootstrap') && config[:salt_bootstrap_options].empty?
          debug("Using bootstrap git to install #{salt_version}")
          config[:salt_bootstrap_options] = "-P git v#{salt_version}"
        end

        install_template = File.expand_path("./../install.erb", __FILE__)

        ERB.new(File.read(install_template)).result(binding)
      end

      def install_chef
        return unless config[:require_chef]
        chef_url = config[:chef_bootstrap_url]
        omnibus_download_dir = config[:omnibus_cachier] ? '/tmp/vagrant-cache/omnibus_chef' : '/tmp'
        <<-INSTALL
          if [ ! -d "/opt/chef" ]
          then
            echo "-----> Installing Chef Omnibus (for busser/serverspec ruby support)"
            mkdir -p #{omnibus_download_dir}
            if [ ! -x #{omnibus_download_dir}/install.sh ]
            then
              do_download #{chef_url} #{omnibus_download_dir}/install.sh
            fi
            #{sudo('sh')} #{omnibus_download_dir}/install.sh -d #{omnibus_download_dir}
          fi
        INSTALL
      end

      def create_sandbox
        super
        prepare_data
        prepare_minion
        prepare_pillars
        prepare_grains
        prepare_states
        prepare_state_top
      end

      def init_command
        debug("Initialising Driver #{name} by cleaning #{config[:root_path]}")
        "#{sudo('rm')} -rf #{config[:root_path]} ; mkdir -p #{config[:root_path]}"
      end

      def salt_command
        salt_version = config[:salt_version]
        cmd = sudo("salt-call --config-dir=#{File.join(config[:root_path], config[:salt_config])} --local state.highstate")
        cmd << " --log-level=#{config[:log_level]}" if config[:log_level]
        cmd << " --id=#{config[:salt_minion_id]}" if config[:salt_minion_id]
        cmd << " test=#{config[:dry_run]}" if config[:dry_run]
        if salt_version > RETCODE_VERSION || salt_version == 'latest'
          # hope for the best and hope it works eventually
          cmd += ' --retcode-passthrough'
        end
        cmd
      end

      def run_command
        debug("running driver #{name}")
        debug(diagnose)

        # config[:salt_version] can be 'latest' or 'x.y.z', 'YYYY.M.x' etc
        # error return codes are a mess in salt:
        #  https://github.com/saltstack/salt/pull/11337
        # Unless we know we have a version that supports --retcode-passthrough
        # attempt to scan the output for signs of failure
        if config[:salt_version] <= RETCODE_VERSION
          # scan the output for signs of failure, there is a risk of false negatives
          fail_grep = 'grep -e Result.*False -e Data.failed.to.compile -e No.matching.sls.found.for'
          # capture any non-zero exit codes from the salt-call | tee pipe
          cmd = 'set -o pipefail ; ' << salt_command
          # Capture the salt-call output & exit code
          cmd << ' 2>&1 | tee /tmp/salt-call-output ; SC=$? ; echo salt-call exit code: $SC ;'
          # check the salt-call output for fail messages
          cmd << " (sed '/#{fail_grep}/d' /tmp/salt-call-output | #{fail_grep} ; EC=$? ; echo salt-call output grep exit code ${EC} ;"
          # use the non-zer exit code from salt-call, then invert the results of the grep for failures
          cmd << ' [ ${SC} -ne 0 ] && exit ${SC} ; [ ${EC} -eq 0 ] && exit 1 ; [ ${EC} -eq 1 ] && exit 0)'
          cmd
        else
          salt_command
        end
      end

      protected

      def prepare_data
        return unless config[:data_path]

        info('Preparing data')
        debug("Using data from #{config[:data_path]}")

        tmpdata_dir = File.join(sandbox_path, 'data')
        FileUtils.mkdir_p(tmpdata_dir)
        cp_r_with_filter(config[:data_path], tmpdata_dir, config[:salt_copy_filter])
      end

      def prepare_minion
        info('Preparing salt-minion')

        minion_template = File.expand_path("./../minion.erb", __FILE__)

        minion_config_content = ERB.new(File.read(minion_template)).result(binding)

        # create the temporary path for the salt-minion config file
        debug("sandbox is #{sandbox_path}")
        sandbox_minion_config_path = File.join(sandbox_path, config[:salt_minion_config])

        write_raw_file(sandbox_minion_config_path, minion_config_content)
      end

      def prepare_grains
        debug("Grains Hash: #{config[:grains]}")

        return if config[:grains].nil?

        info("Preparing grains into #{config[:salt_config]}/grains")

        # generate the filename
        sandbox_grains_path = File.join(sandbox_path, config[:salt_config], 'grains')
        debug("sandbox_grains_path: #{sandbox_grains_path}")

        write_hash_file(sandbox_grains_path, config[:grains])
      end
    end
  end
end
