# -*- encoding: utf-8 -*-

require "kitchen/verifier/base"

module Kitchen
  module Verifier
    class Runtests < Kitchen::Verifier::Base
      kitchen_verifier_api_version 1

      plugin_version Kitchen::VERSION

      default_config :testingdir, '/tmp/kitchen/testing'
      default_config :python_bin, 'python2'
      default_config :verbose, false
      default_config :run_destructive, false
      default_config :xml, false
      default_config :coverage_xml, false
      default_config :types, []
      default_config :transport, false
      default_config :save, {}

      def call(state)
        info("[#{name}] Verify on instance #{instance.name} with state=#{state}")
        command = [
          config[:python_bin],
          File.join(config[:testingdir], '/tests/runtests.py'),
          '--sysinfo',
          '--output-columns=80',
          (config[:transport] ? "--transport=#{config[:transport]}" : ''),
          (config[:verbose] ? '-v' : ''),
          (config[:run_destructive] ? "--run-destructive" : ''),
          (config[:coverage_xml] ? "--coverage-xml=#{config[:coverage_xml]}" : ''),
          (config[:xml] ? "--xml=#{config[:xml]}" : ''),
          config[:types].collect{|type| "--#{type}"}.join(' '),
          config[:tests].collect{|test| "-n #{test}"}.join(' '),
        ].join(' ')
        instance.transport.connection(state) do |conn|
          begin
            conn.execute(sudo(command))
          ensure
            config[:save].each do |remote, local|
              conn.execute(sudo("chmod -R +r #{remote}"))
              conn.download(remote, local)
            end
          end
        end
        debug("[#{name}] Verify completed.")
      end
    end
  end
end
