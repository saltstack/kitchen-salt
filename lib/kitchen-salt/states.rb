module Kitchen
  module Salt
    module States
      private

      def prepare_state_top
        info('Preparing state_top')

        sandbox_state_top_path = File.join(sandbox_path, config[:salt_state_top])

        if config[:state_top_from_file] == false
          # use the top.sls embedded in .kitchen.yml

          # we get a hash with all the keys converted to symbols, salt doesn't like this
          # to convert all the keys back to strings again
          state_top_content = unsymbolize(config[:state_top]).to_yaml
          # .to_yaml will produce ! '*' for a key, Salt doesn't like this either
          state_top_content.gsub!(/(!\s'\*')/, "'*'")
        else
          # load a top.sls from disk
          if config[:local_salt_root].nil?
            top_file = 'top.sls'
          else
            top_file = File.join(config[:local_salt_root], 'salt/top.sls')
          end
          state_top_content = File.read(top_file)
        end

        write_raw_file(sandbox_state_top_path, state_top_content)
      end

      def prepare_states
        if config[:state_collection] || config[:is_file_root] || !config[:local_salt_root].nil?
          prepare_state_collection
        else
          prepare_formula config[:kitchen_root], config[:formula]
          prepare_vendor_states
        end

      end

      def prepare_vendor_states
        vendor_path = config[:vendor_path]

        unless vendor_path.nil?
          if Pathname.new(vendor_path).exist?
            Dir[File.join(vendor_path, '*')].each do |d|
              prepare_formula vendor_path, File.basename(d)
            end
          else
            # :vendor_path was set, but not valid
            raise UserError, "kitchen-salt: Invalid vendor_path set: #{vendor_path}"
          end
        end
      end

      def prepare_formula_dir(path, subdir)
        src = File.join(path, subdir)

        if File.directory?(src)
          debug("prepare_formula_dir: #{src} exists, copying..")
          subdir_path = File.join(sandbox_path, config[:salt_file_root], subdir)
          FileUtils.mkdir_p(subdir_path)
          cp_r_with_filter(src, subdir_path, config[:salt_copy_filter])
        else
          debug("prepare_formula_dir: #{src} doesn't exist, skipping.")
        end
      end

      def prepare_formula(path, formula)
        info("Preparing formula: #{formula} from #{path}")
        debug("Using config #{config}")

        formula_dir = File.join(sandbox_path, config[:salt_file_root], formula)
        FileUtils.mkdir_p(formula_dir)
        cp_r_with_filter(File.join(path, formula), formula_dir, config[:salt_copy_filter])

        # copy across the _modules etc directories for python implementation
        %w(_modules _states _grains _renderers _returners).each do |extrapath|
          prepare_formula_dir(path, extrapath)
        end
      end

      def prepare_state_collection
        info('Preparing state collection')
        collection_name = config[:collection_name]
        formula = config[:formula]

        if collection_name.nil? && formula.nil?
          info('neither collection_name or formula have been set, assuming this is a pre-built collection')
          collection_name = ''
        elsif collection_name.nil?
          collection_name = formula
        end

        if config[:local_salt_root].nil?
          states_location = config[:kitchen_root]
        else
          states_location = File.join(config[:local_salt_root], 'salt')
        end
        collection_dir = File.join(sandbox_path, config[:salt_file_root], collection_name)
        FileUtils.mkdir_p(collection_dir)
        cp_r_with_filter(states_location, collection_dir, config[:salt_copy_filter])
      end
    end
  end
end
