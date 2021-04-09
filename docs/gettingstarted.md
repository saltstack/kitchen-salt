<!--
# @markup markdown
# @title Getting Started
# @author SaltStack Inc.
-->

# Getting Started #

This tutorial is going to be using the following repository: <https://github.com/gtmanfred/wordpress-formula>

## Installation ##

KitchenSalt is a ruby gem, so ruby will be required.  The easiest ways to get an up to date ruby version is to use [rbenv](https://github.com/rbenv/rbenv) or [rvm](https://rvm.io/).  Luckily, a script installer is provided here.

### Installing Ruby ###

#### rbenv ####

For Mac, there is an `rbenv` package in homebrew.

    brew install rbenv

For Linux, there is an [installer script](https://github.com/rbenv/rbenv-installer/tree/master/bin/rbenv-installer).

The following instructions will allow for a global install of rbenv.

1. Install the dependencies for building ruby, referencing the `ruby-build` [Suggested build environment](https://github.com/rbenv/ruby-build/wiki#suggested-build-environment) documentation.

1. clone git repos and setup path

   - [Basic GitHub Checkout/setup of rbenv](https://github.com/rbenv/rbenv#basic-github-checkout)
   - [Installation of `ruby-build`](https://github.com/rbenv/ruby-build#installation)

1. Install ruby and set `2.6.3` as the version to use by default. Salt uses this version of Ruby in CI pipelines, which is why it is preferred here, but newer versions of ruby may work without issue.

       rbenv install 2.6.3
       rbenv local 2.6.3
       # OPTIONAL: Set global default version
       # rbenv global 2.6.3

If gemsets are needed, the [rbenv-gemset](https://github.com/jf/rbenv-gemset) plugin can be added to the gemsets repository.

#### rvm ####

rvm is another method of managing ruby version.

1. Import the gpg key from <https://rvm.io>

       gpg --keyserver hkp://keys.gnupg.net --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3 7D2BAF1CF37B13E2069D6956105BD0E739499BDB

1. Run the installer script

       \curl -sSL https://get.rvm.io | bash -s stable

1. Install and use ruby

       rvm use --install --create ruby@salt

   and rvm will manage installing all of the required packages for managing ruby versions via rvm.  The `@salt` portion creates a specific gemset (`rvm help gemset`).

### Installing KitchenSalt ###

There are a few things that are needed for running kitchen-salt

1. The bundler gem should be installed

       gem install bundler

   This will make the `bundle` command available.  Bundler only lets uses the gems listed in the `Gemfile` in the directory tree where commands are run.

1. Create a gemfile. Now a [kitchen driver](https://docs.chef.io/config_yml_kitchen.html#drivers) will need to be choosen. This tutorial is going to use `kitchen-docker`.

       # Gemfile
       source 'https://rubygems.org'

       gem 'kitchen-salt'
       gem 'kitchen-docker'
       gem 'kitchen-sync'

   `kitchen-sync` is not required for this, but it does copy files to the container faster.

1. Run bundler to install gems.

       bundle install

   This will install all the gems from the Gemfile, and make only those gems available when commands are run with `bundle exec <command>`


For more complicated setups where different methods of running Kitchen are required, groups can be assigned in the Gemfile.

    # Gemfile
    source 'https://rubygems.org'

    gem 'test-kitchen', :git => 'https://github.com/gtmanfred/test-kitchen.git'
    gem 'kitchen-salt', :git => 'https://github.com/saltstack/kitchen-salt.git'
    gem 'kitchen-sync'
    gem 'git'

    group :docker do
      gem 'kitchen-docker', :git => 'https://github.com/test-kitchen/kitchen-docker.git'
    end

    group :windows do
      gem 'vagrant-wrapper'
      gem 'kitchen-vagrant'
      gem 'winrm', '~>2.0'
      gem 'winrm-fs', :git => 'https://github.com/gtmanfred/winrm-fs.git'
    end

To specify only installing certain groups, use the `--with` and `--without` arguements

    bundle install --with windows --without docker

## Setup ##

Now the `.kitchen.yml` file needs to be setup for running tests. The following sections should be copied into the {file:docs/example-kitchen.yml.md} file in the root of the directory for the `wordpress-formula`

### driver ###

The driver needs to be setup to build the test instance correctly.

    driver:
      name: docker
      use_sudo: false
      privileged: true
      forward:
        - 80

The example will be using docker.  If `sudo` is required to run the docker command to build containers, then `use_sudo` should be set to True. The `privileged` options enables the container to run systemd as the Exec Command for the docker container.  And lastly, port 80 will be forwarded to the host so that the tests can check that the wordpress website is running.

If different platforms or different suites need to have different driver configurations, they can be set in the `driver_config`.

### transport ###

Here is where the `kitchen-sync` transport is specified.

    transport:
      name: sftp

If windows is being tested, `winrm-transport` will probably be required for the `winrm` transport.

### platforms ###

This section is where the distributions and operating systems that will be tested are specified. Because different distributions put the systemd binary in different places, the `run_command` is specified here in the `driver_config`.

    platforms:
      - name: centos
        driver_config:
          run_command: /usr/lib/systemd/systemd

### suites ###

This is the section where the different test suites are specified.  Common uses will be to test different paths through the formulas or different versions of salt with the same formula.

    suites:
      - name: nitrogen
        provisioner:
          salt_bootstrap_options: -X -p git stable 2017.7
      - name: carbon
        provisioner:
          salt_bootstrap_options: -X -p git stable 2016.11

Because different versions of salt are being tested, different `salt_bootstrap_options` are used.

### verifier ###

The verifier is where the testing to check if the states run was successfull.

    verifier:
      name: shell
      remote_exec: false
      command: pytest -v tests/integration/

In the `wordpress-formula`, pytest is used to make http calls to the server to check that the wordpress website is up, and configured the way that it was specified.  There are several other things that could be used here:

- [testinfra](https://pypi.python.org/pypi/testinfra)
- [busser](https://github.com/test-kitchen/busser)
- [InSpec](https://www.chef.io/inspec/)
- [Serverspec](http://serverspec.org/)

And then basically any other unit test framework that could be run from the shell could be used to replace the one above.

### provisioner ###

This is what kitchen-salt actually provides.

    provisioner:
      name: salt_solo
      salt_install: bootstrap
      is_file_root: true
      require_chef: false
      salt_copy_filter:
        - .git
      dependencies:
        - name: apache
          repo: git
          source: https://github.com/saltstack-formulas/apache-formula.git
        - name: mysql
          repo: git
          source: https://github.com/saltstack-formulas/mysql-formula.git
        - name: php
          repo: git
          source: https://github.com/saltstack-formulas/php-formula.git
      state_top:
        base:
          "*":
            - wordpress
      pillars:
        top.sls:
          base:
            "*":
              - wordpress
      pillars_from_files:
        wordpress.sls: pillar.example

In this, the salt provisioner is specified by the name `salt_solo`.  The [salt-bootstrap](https://github.com/saltstack/salt-bootstrap) script is used to install salt. The option `is_file_root` specifies that the top level directory of this git repository should be copied to the salt `file_root` in the test instance. Since ruby is not being used to test the instance in the verifier step, `require_chef` is set to `False`.

Next, the `dependencies` are different repositories that the `wordpress-formula` depends on to be available to work correctly.  The `state_top` specifies the top file that will be applied. Like the `state_top`, the `pillars` and `pillars_from_files` directives specifies different files to drop into the salt `pillar_roots` on the test instance. If there are multiple groups of state or pillar files that can be tested independently, it would probably be useful to specify the extra ones under the different suites.

## Run Tests ##

Now that TestKitchen is all setup, the `wordpress-formula` can be tested and verified.

First, kitchen commands that will be useful.

- list: show the current state of each configured environment
- create: create the test environment with ssh or winrm.
- converge: run the provision command, in this case, salt_solo and the specified states
- verify: run the verifier.
- login: login to created environment
- destroy: remove the created environment
- test: run create, converge, verify, and then destroy if it all succeeds

And since this formula is being tested by [pytest](https://docs.pytest.org/en/latest/), it will need to be installed.

    pip install -r requirements

The above command will install requests and testinfra, which will also pull in the pytest dependency which is required by testinfra.

Now the following commands can finally be run.

    bundle exec kitchen list
    bundle exec kitchen create
    bundle exec kitchen converge
    bundle exec kitchen verify
    bundle exec kitchen destroy

Or to simplify it

    bundle exec kitchen test

With either of these, test-kitchen will do the following

1. Create the instance using the method specified by the `driver`.
1. Install salt and run the specified states defined in the provisioner (This step is called converging).
1. Run the test suite verifier.
1. Destroy the instance if everything passed.

If `kitchen test` was run, then the `kitchen list` command will show all the instances and what the result of their last command was.

## Run test interactivaly ##

If your `converge` or `verify` step is failing, by default `kitchen` will keep your VM running, so you can login using 
ssh and debug things from there. To run the `state.apply` that converge is doing, run the following : 

    kitchen login
    sudo salt-call --config-dir=/tmp/kitchen/etc/salt/ --log-level=debug state.apply 

If you are using the `minion_id` argument run : 

    kitchen login
    sudo salt-call --config-dir=/tmp/kitchen/etc/salt/ --log-level=debug --id=salt-minion-id state.apply

## Closing ##

This instance is now tested.  For more information about `kitchen-salt` and `test-kitchen` in general please see the following links:

- {file:docs/provisioner_options.md}
- [Kitchen Salt](https://github.com/saltstack/kitchen-salt)
- [Test Kitchen Docs](https://docs.chef.io/kitchen.html)
- [KitchenCI](http://kitchen.ci/)
- [Test Kitchen Github](https://github.com/test-kitchen)
