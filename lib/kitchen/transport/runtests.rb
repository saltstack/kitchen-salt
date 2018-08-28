require 'kitchen/transport/rsync'
require 'shellwords'

module Kitchen
  module Transport
    class Runtests < Kitchen::Transport::Rsync
      class Connection < Kitchen::Transport::Rsync::Connection
        def execute_with_exit_code(command)
          if command.start_with?("sh -c")
            super
          else
            login = login_command()
            cmd = [
              login.instance_variable_get("@command"),
              login.instance_variable_get("@arguments").join(' '),
              '--',
              command.shellescape,
            ].join(' ')
            system(cmd)
            $?.exitstatus
          end
        end
      end
    end
  end
end
