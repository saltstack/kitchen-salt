module Kitchen
  module Salt
    module Pillars
      private

      def prepare_pillars
        info("Preparing pillars into #{config[:salt_pillar_root]}")

        pillars = config[:pillars]
        pillars_from_files = config[:'pillars-from-files']
        debug("Pillars Hash: #{pillars}")

        if pillars.nil? && pillars_from_files.nil?
          if not config[:local_salt_root].nil?
            pillars_location = File.join(config[:local_salt_root], 'pillar')
            sandbox_pillar_path = File.join(sandbox_path, config[:salt_pillar_root])
            cp_r_with_filter(pillars_location, sandbox_pillar_path, config[:salt_copy_filter])
            return
          end
          return
        end

        # we get a hash with all the keys converted to symbols, salt doesn't like this
        # to convert all the keys back to strings again
        pillars = unsymbolize(pillars)
        debug("unsymbolized pillars hash: #{pillars}")

        # write out each pillar (we get key/contents pairs)
        prepare_pillar_files(pillars)

        # copy the pillars from files straight across, as YAML.load/to_yaml and
        # munge multiline strings
        unless pillars_from_files.nil?
          prepare_pillars_from_files(pillars_from_files)
        end
      end

      def prepare_pillar_files(pillars)
        pillars.each do |key, contents|
          # convert the hash to yaml
          pillar = contents.to_yaml

          # .to_yaml will produce ! '*' for a key, Salt doesn't like this either
          pillar.gsub!(/(!\s'\*')/, "'*'")

          # generate the filename
          sandbox_pillar_path = File.join(sandbox_path, config[:salt_pillar_root], key)

          debug("Rendered pillar yaml for #{key}:\n #{pillar}")
          write_raw_file(sandbox_pillar_path, pillar)
        end
      end

      def copy_pillar(key, srcfile)
        debug("Copying external pillar: #{key}, #{srcfile}")
        # generate the filename
        sandbox_pillar_path = File.join(sandbox_path, config[:salt_pillar_root], key)
        # create the directory where the pillar file will go
        FileUtils.mkdir_p(File.dirname(sandbox_pillar_path))
        # copy the file across
        FileUtils.copy srcfile, sandbox_pillar_path
      end

      def prepare_pillars_from_files(pillars)
        external_pillars = unsymbolize(pillars)
        debug("external_pillars (unsymbolize): #{external_pillars}")
        external_pillars.each do |key, srcfile|
          copy_pillar(key, srcfile)
        end
      end
    end
  end
end
