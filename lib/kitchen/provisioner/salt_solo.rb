# -*- encoding: utf-8 -*-
#
# Author:: Chris Lundquist (<chris.lundquist@github.com>)
#
# Copyright (C) 2013, Chris Lundquist
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

module Kitchen

  module Provisioner

    # Basic shell provisioner.
    #
    # @author Chris Lundquist (<chris.ludnquist@github.com>)
    class SaltSolo < Base

      default_config :salt_bootstrap, true
      default_config :salt_bootstrap, "http://bootstrap.saltstack.org"
      default_config :salt_bootstrap_options, ""

      default_config :salt_minion_config, "/etc/salt/minion"
      default_config :salt_file_root, "/srv/salt"
      default_config :salt_pillar_root, "/srv/pillar"
      default_config :salt_state_top, "/srv/salt/top.sls"
      default_config :salt_run_highstate, true

      def install_command
        return unless config[:salt_autoinstaller]

        url = config[:salt_bootstrap_url]
        bootstrap_options = config[:salt_bootstrap_options]
        <<-INSTALL
          sh -c '
          #{Util.shell_helpers}

          do_download #{url} /tmp/bootstrap-salt.sh
          #{sudo('sh')} /tmp/bootstrap-salt.sh #{bootstrap_options}
          '
        INSTALL
      end

      def create_sandbox
        super
        prepare_data
        prepare_minion
        prepare_state_top
        prepare_formula
      end

      def init_command
        data = File.join(config[:root_path], "data")
        "#{sudo('rm')} -rf #{data} ; mkdir -p #{config[:root_path]}"
      end

      def run_command
        # sudo(File.join(config[:root_path], File.basename(config[:script])))
        info(diagnose())
        if config[:salt_run_highstate]
          sudo("salt-call --config-dir=#{config[:minion_config_path]} --local state.highstate")
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
        info("sandbox is #{sandbox_path}")
        sandbox_minion_config_path = File.join(sandbox_path, config[:salt_minion_config])

        # create the directory & drop the file in
        FileUtils.mkdir_p(File.dirname(sandbox_minion_config_path))
        File.open(sandbox_minion_config_path, "wb") do |file|
          file.write(minion_config_content)
        end

      end

      def prepare_state_top
        info("Preparing state_top")

        state_top_content = <<-STATE_TOP.gsub(/^ {10}/, '')
          base:
            '*':
              - #{config[:formula]}
        STATE_TOP

        sandbox_state_top_path = File.join(sandbox_path, config[:salt_state_top])

        # create the directory & drop the file in
        FileUtils.mkdir_p(File.dirname(sandbox_state_top_path))
        File.open(sandbox_state_top_path, "wb") do |file|
          file.write(state_top_content)
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
