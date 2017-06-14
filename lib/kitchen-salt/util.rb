require 'find'

module Kitchen
  module Salt
    module Util
      private

      def unsymbolize(obj)
        if obj.is_a? Hash
          obj.each_with_object({}) do |(k, v), a|
            a[k.to_s] = unsymbolize(v)
            a
          end
        elsif obj.is_a? Array
          obj.each_with_object([]) do |e, a|
            a << unsymbolize(e)
            a
          end
        else
          obj
        end
      end

      def cp_r_with_filter(source_paths, target_path, filter = [])
        debug("cp_r_with_filter:source_paths = #{source_paths}")
        debug("cp_r_with_filter:target_path = #{target_path}")
        debug("cp_r_with_filter:filter = #{filter}")

        Array(source_paths).each do |source_path|
          _cp_r_with_filter(source_path, target_path, filter)
        end
      end

      def _cp_r_with_filter(source_path, target_path, filter = [])
        Find.find(source_path) do |source|
          target = source.sub(/^#{source_path}/, target_path)
          debug("cp_r_with_filter:source = #{source}")
          debug("cp_r_with_filter:target = #{target}")
          filtered = filter.include?(File.basename(source))
          if File.directory? source
            if filtered
              debug("Found #{source} in #{filter}, pruning it from the Find")
              Find.prune
            end
            FileUtils.mkdir_p target unless File.exist? target

            FileUtils.cp_r "#{source}/.", target if File.symlink? source
          elsif filtered
            debug("Found #{source} in #{filter}, not copying file")
          else
            FileUtils.copy source, target
          end
        end
      end

      def write_raw_file(name, contents)
        FileUtils.mkdir_p(File.dirname(name))
        File.open(name, 'wb') do |file|
          file.write(contents)
        end
      end

      def write_hash_file(name, contents)
        raw_contents = unsymbolize(contents).to_yaml
        write_raw_file(name, raw_contents)
      end
    end
  end
end
