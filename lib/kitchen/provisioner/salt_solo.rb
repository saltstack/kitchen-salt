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
require 'find'
require 'fileutils'
require 'yaml'

module Kitchen

  module Provisioner

    # Basic Salt Masterless Provisioner, based on work by
    #
    # @author Chris Lundquist (<chris.ludnquist@github.com>)
    class SaltSolo < Base

      default_config :salt_version, "latest"

      # supported install methods: bootstrap|apt
      default_config :salt_install, "bootstrap"

      default_config :salt_bootstrap_url, "http://bootstrap.saltstack.org"
      default_config :salt_bootstrap_options, ""

      # alternative method of installing salt
      default_config :salt_apt_repo, "http://apt.mccartney.ie"
      default_config :salt_apt_repo_key, "http://apt.mccartney.ie/KEY"

      default_config :chef_bootstrap_url, "https://www.getchef.com/chef/install.sh"

      default_config :salt_config, "/etc/salt"
      default_config :salt_minion_config, "/etc/salt/minion"
      default_config :salt_file_root, "/srv/salt"
      default_config :salt_pillar_root, "/srv/pillar"
      default_config :salt_state_top, "/srv/salt/top.sls"
      default_config :state_collection, false
      default_config :state_top, {}
      default_config :state_top_from_file, false
      default_config :salt_run_highstate, true
      default_config :salt_copy_filter, []
      default_config :is_file_root, false

      default_config :dependencies, []
      default_config :vendor_path, ""
      default_config :omnibus_cachier, false

      # salt-call version that supports the undocumented --retcode-passthrough command
      RETCODE_VERSION = '0.17.5'

      def install_command
        debug(diagnose())

        # if salt_verison is set, bootstrap is being used & bootstrap_options is empty,
        # set the bootstrap_options string to git install the requested version
        if ((config[:salt_version] != 'latest') && (config[:salt_install] == 'bootstrap') && config[:salt_bootstrap_options].empty?)
          debug("Using bootstrap git to install #{config[:salt_version]}")
          config[:salt_bootstrap_options] = "-P git v#{config[:salt_version]}"
        end

        salt_install = config[:salt_install]

        salt_url = config[:salt_bootstrap_url]
        chef_url = config[:chef_bootstrap_url]
        bootstrap_options = config[:salt_bootstrap_options]

        salt_version = config[:salt_version]
        salt_apt_repo = config[:salt_apt_repo]
        salt_apt_repo_key = config[:salt_apt_repo_key]

        omnibus_download_dir = config[:omnibus_cachier] ? "/tmp/vagrant-cache/omnibus_chef" : "/tmp"

        <<-INSTALL
          sh -c '
          #{Util.shell_helpers}

          # what version of salt is installed?
          SALT_VERSION=`salt-call --version | cut -d " " -f 2`


          if [ -z "${SALT_VERSION}" -a "#{salt_install}" = "bootstrap" ]
          then
            do_download #{salt_url} /tmp/bootstrap-salt.sh
            #{sudo('sh')} /tmp/bootstrap-salt.sh #{bootstrap_options}
          elif [ -z "${SALT_VERSION}" -a "#{salt_install}" = "apt" ]
          then
            . /etc/lsb-release

            echo "deb #{salt_apt_repo}/salt-#{salt_version} ${DISTRIB_CODENAME} main" | #{sudo('tee')} /etc/apt/sources.list.d/salt-#{salt_version}.list

            do_download #{salt_apt_repo_key} /tmp/repo.key
            #{sudo('apt-key')} add /tmp/repo.key

            #{sudo('apt-get')} update
            #{sudo('apt-get')} install -y salt-minion
          fi

          # check again, now that an install of some form should have happened
          SALT_VERSION=`salt-call --version | cut -d " " -f 2`

          if [ -z "${SALT_VERSION}" ]
          then
            echo "No salt-minion installed, install must have failed!!"
            echo "salt_install = #{salt_install}"
            echo "salt_url = #{salt_url}"
            echo "bootstrap_options = #{bootstrap_options}"
            echo "salt_version = #{salt_version}"
            echo "salt_apt_repo = #{salt_apt_repo}"
            echo "salt_apt_repo_key = #{salt_apt_repo_key}"
            exit 2
          elif [ "${SALT_VERSION}" = "#{salt_version}" -o "#{salt_version}" = "latest" ]
          then
            echo "You asked for #{salt_version} and you have ${SALT_VERSION} installed, sweet!"
          elif [ ! -z "${SALT_VERSION}" -a "#{salt_install}" = "bootstrap" ]
          then
            echo "You asked for bootstrap install and you have got ${SALT_VERSION}, hope thats ok!"
          else
            echo "You asked for #{salt_version} and you have got ${SALT_VERSION} installed, dunno how to fix that, sorry!"
            exit 2
          fi

          if [ ! -d "/opt/chef" ]
          then
            echo "-----> Installing Chef Omnibus"
            mkdir -p #{omnibus_download_dir}
            if [ ! -x #{omnibus_download_dir}/install.sh ]
            then
              do_download #{chef_url} #{omnibus_download_dir}/install.sh
            fi
            #{sudo('sh')} #{omnibus_download_dir}/install.sh -d #{omnibus_download_dir}
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
        prepare_grains
        if config[:state_collection] || config[:is_file_root]
          prepare_state_collection
        else
          prepare_formula config[:kitchen_root], config[:formula]

          deps = if Pathname.new(config[:vendor_path]).absolute?
            Dir["#{config[:vendor_path]}/*"]
          else
            Dir["#{config[:kitchen_root]}/#{config[:vendor_path]}/*"]
          end

          deps.each do |d|
            prepare_formula "#{config[:kitchen_root]}/#{config[:vendor_path]}", File.basename(d)
          end

          config[:dependencies].each do |formula|
            prepare_formula formula[:path], formula[:name]
          end
        end
      end

      def init_command
        debug("Initialising Driver #{self.name} by cleaning #{config[:root_path]}")
        "#{sudo('rm')} -rf #{config[:root_path]} ; mkdir -p #{config[:root_path]}"
      end

      def run_command
        debug("running driver #{self.name}")
        # sudo(File.join(config[:root_path], File.basename(config[:script])))
        debug(diagnose())
        if config[:salt_run_highstate]
          cmd = sudo("salt-call --config-dir=#{File.join(config[:root_path], config[:salt_config])} --local state.highstate")
        else
          cmd = sudo("salt-call state.highstate")
        end

        cmd << " --log-level=#{config[:log_level]}"

        # config[:salt_version] can be 'latest' or 'x.y.z', 'YYYY.M.x' etc
        # error return codes are a mess in salt:
        #  https://github.com/saltstack/salt/pull/11337
        # Unless we know we have a version that supports --retcode-passthrough
        # attempt to scan the output for signs of failure
        if config[:salt_version] > RETCODE_VERSION && config[:salt_version] != 'latest'
          # hope for the best and hope it works eventually
          cmd = cmd + " --retcode-passthrough"
        end

        # scan the output for signs of failure, there is a risk of false negatives
        fail_grep = 'grep -e Result.*False -e Data.failed.to.compile -e No.matching.sls.found.for'
        # capture any non-zero exit codes from the salt-call | tee pipe
        cmd = 'set -o pipefail ; ' << cmd
        # Capture the salt-call output & exit code
        cmd << " 2>&1 | tee /tmp/salt-call-output ; SC=$? ; echo salt-call exit code: $SC ;"
        # check the salt-call output for fail messages
        cmd << " (sed '/#{fail_grep}/d' /tmp/salt-call-output | #{fail_grep} ; EC=$? ; echo salt-call output grep exit code ${EC} ;"
        # use the non-zer exit code from salt-call, then invert the results of the grep for failures
        cmd << " [ ${SC} -ne 0 ] && exit ${SC} ; [ ${EC} -eq 0 ] && exit 1 ; [ ${EC} -eq 1 ] && exit 0)"

        cmd
      end

      protected

      def prepare_data
        return unless config[:data_path]

        info("Preparing data")
        debug("Using data from #{config[:data_path]}")

        tmpdata_dir = File.join(sandbox_path, "data")
        FileUtils.mkdir_p(tmpdata_dir)
        #FileUtils.cp_r(Dir.glob("#{config[:data_path]}/*"), tmpdata_dir)
        cp_r_with_filter(config[:data_path], tmpdata_dir, config[:salt_copy_filter])
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

        sandbox_state_top_path = File.join(sandbox_path, config[:salt_state_top])

        if (config[:state_top_from_file] == false)
          # use the top.sls embedded in .kitchen.yml

          # we get a hash with all the keys converted to symbols, salt doesn't like this
          # to convert all the keys back to strings again
          state_top_content = unsymbolize(config[:state_top]).to_yaml
          # .to_yaml will produce ! '*' for a key, Salt doesn't like this either
          state_top_content.gsub!(/(!\s'\*')/, "'*'")
        else
          # load a top.sls from disk
          state_top_content = File.read("top.sls")
        end

        # create the directory & drop the file in
        FileUtils.mkdir_p(File.dirname(sandbox_state_top_path))
        File.open(sandbox_state_top_path, "wb") do |file|
          file.write(state_top_content)
        end
      end

      def prepare_pillars
        info("Preparing pillars into #{config[:salt_pillar_root]}")
        debug("Pillars Hash: #{config[:pillars]}")

        return if config[:pillars].nil? && config[:'pillars-from-files'].nil?



        # we get a hash with all the keys converted to symbols, salt doesn't like this
        # to convert all the keys back to strings again
        pillars = unsymbolize(config[:pillars])
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

        # copy the pillars from files straight across, as YAML.load/to_yaml and
        # munge multiline strings
        if !config[:'pillars-from-files'].nil?
          external_pillars = unsymbolize(config[:'pillars-from-files'])
          debug("external_pillars (unsymbolize): #{external_pillars}")
          external_pillars.each do |key, srcfile|
            debug("Copying external pillar: #{key}, #{srcfile}")
            # generate the filename
            sandbox_pillar_path = File.join(sandbox_path, config[:salt_pillar_root], key)
            # create the directory where the pillar file will go
            FileUtils.mkdir_p(File.dirname(sandbox_pillar_path))
            # copy the file across
            FileUtils.copy srcfile, sandbox_pillar_path
          end
        end
      end

      def prepare_grains
        debug("Grains Hash: #{config[:grains]}")

        return if config[:grains].nil?

        info("Preparing grains into #{config[:salt_config]}/grains")
        # we get a hash with all the keys converted to symbols, salt doesn't like this
        # to convert all the keys back to strings again we use unsymbolize
        # then we convert the hash to yaml
        grains = unsymbolize(config[:grains]).to_yaml

        # generate the filename
        sandbox_grains_path = File.join(sandbox_path, config[:salt_config], 'grains')
        debug("sandbox_grains_path: #{sandbox_grains_path}")

        # create the directory where the pillar file will go
        FileUtils.mkdir_p(File.dirname(sandbox_grains_path))

        debug("Rendered grains yaml")
        # create the directory & drop the file in
        File.open(sandbox_grains_path, "wb") do |file|
          file.write(grains)
        end
      end

      def prepare_formula(path, formula)
        info("Preparing formula: #{formula} from #{path}")
        debug("Using config #{config}")

        formula_dir = File.join(sandbox_path, config[:salt_file_root], formula)
        FileUtils.mkdir_p(formula_dir)
        cp_r_with_filter(File.join(path, formula), formula_dir, config[:salt_copy_filter])

        # copy across the _modules etc directories for python implementation
        ['_modules', '_states', '_grains', '_renderers', '_returners'].each do |extrapath|
          src = File.join(path, extrapath)

          if (File.directory?(src))
            debug("prepare_formula: #{src} exists, copying..")
            extrapath_dir = File.join(sandbox_path, config[:salt_file_root], extrapath)
            FileUtils.mkdir_p(extrapath_dir)
            #FileUtils.cp_r(Dir.glob(File.join(src, "*")), extrapath_dir)
            cp_r_with_filter(src, extrapath_dir, config[:salt_copy_filter])
          else
            debug("prepare_formula: #{src} doesn't exist, skipping.")
          end
        end
      end

      def prepare_state_collection
        info("Preparing state collection")
        debug("Using config #{config}")

        if config[:collection_name].nil? and config[:formula].nil?
          info("neither collection_name or formula have been set, assuming this is a pre-built collection")
          config[:collection_name] = ""
        else
          if config[:collection_name].nil?
            debug("collection_name not set, using #{config[:formula]}")
            config[:collection_name] = config[:formula]
          end
        end

        debug("sandbox_path = #{sandbox_path}")
        debug("salt_file_root = #{config[:salt_file_root]}")
        debug("collection_name = #{config[:collection_name]}")
        collection_dir = File.join(sandbox_path, config[:salt_file_root], config[:collection_name])
        FileUtils.mkdir_p(collection_dir)
        cp_r_with_filter(config[:kitchen_root], collection_dir, config[:salt_copy_filter])

      end

      def cp_r_with_filter(source_path, target_path, filter=[])
        debug("cp_r_with_filter:source_path = #{source_path}")
        debug("cp_r_with_filter:target_path = #{target_path}")
        debug("cp_r_with_filter:filter = #{filter}")

        Array(source_path).each do |source_path|
          Find.find(source_path) do |source|
            target = source.sub(/^#{source_path}/, target_path)
            debug("cp_r_with_filter:source = #{source}")
            debug("cp_r_with_filter:target = #{target}")
            if File.directory? source
              if filter.include?(File.basename(source))
                debug("Found #{source} in #{filter}, pruning it from the Find")
                Find.prune
              end
              FileUtils.mkdir target unless File.exists? target
              if File.symlink? source
                FileUtils.cp_r "#{source}/.", target
              end
            else
              FileUtils.copy source, target
            end
          end
        end
      end
    end
  end
end
