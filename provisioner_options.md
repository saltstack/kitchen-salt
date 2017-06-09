
# Provisioner Options

key | default value | Notes
----|---------------|--------
dry_run | false | Setting this to True makes the highstate to run with flag test=True (Ideal for testing states syntax)
formula | | name of the formula, used to derive the path we need to copy to the guest
[is_file_root](#is_file_root) | false | Treat this project as a complete file_root, not just a state collection or formula
log_level | | set salt logging level when running commands (e.g. specifying `debug` is equivalent of `-l debug`)
salt_install| "bootstrap" | Method by which to install salt, "bootstrap", "apt", "distrib" or "ppa"
salt_bootstrap_url | "https://bootstrap.saltstack.com" | location of bootstrap script
[salt_bootstrap_options](#salt_bootstrap_options) | | optional options passed to the salt bootstrap script
salt_version | "latest"| desired version, only affects apt installs
salt_apt_repo | "https://repo.saltstack.com/apt/ubuntu/16.04/amd64/latest"| apt repo. For more information check [SaltStack Package Repo](https://repo.saltstack.com/)
salt_apt_repo_key| "https://repo.saltstack.com/apt/ubuntu/16.04/amd64/latest/SALTSTACK-GPG-KEY.pub"| apt repo key. For more information check [SaltStack Package Repo](https://repo.saltstack.com/)
salt_ppa | "ppa:saltstack/salt" | Official Ubuntu SaltStack PPA
bootstrap_url| "https://raw.githubusercontent.com/saltstack/kitchen-salt/master/assets/install.sh"| A bootstrap script used to provide Ruby (`ruby` and `ruby-dev`) required for the serverspec test runner on the guest OS. If this script is unable to setup Ruby, it will fallback to using Chef bootstrap installer (set via `chef_bootstrap_url`)
chef_bootstrap_url| "https://www.getchef.com/chef/install.sh"| the chef bootstrap installer, used to provide Ruby for the serverspec test runner on the guest OS. However required is only a ruby, under assets/install.sh is an alternative (Chef free) bootstrap script prom PR#42. Example no-"chef_bootstrap url": https://raw.githubusercontent.com/saltstack/kitchen-salt/assets/install.sh
require_chef | true | Install chef ( needed by busser to run tests, if no verification driver is specified in kitchen yml)
salt_config| "/etc/salt"|
[salt_copy_filter](#salt_copy_filter) | [] | List of filenames to be excluded when copying states, formula & pillar data down to guest instances.
salt_minion_config| "/etc/salt/minion"|
salt_minion_config_template| nil | a local file used to customize minion config. The default one is provided by kitchen-salt (`lib/kitchen/provisioner/minion.erb`)
salt_minion_id| | Customize Salt minion_id (by default Salt uses machine hostname)
salt_env| "base"| environment to use in minion config file
salt_file_root| "/srv/salt"|
salt_pillar_root| "/srv/pillar"|
salt_state_top| "/srv/salt/top.sls"|
salt_run_highstate| true |
[state_top](#state_top)| {} | states that should be applied, in standard top.sls format
[state_top_from_file](#state_top_from_file) | false |
state_collection | false | treat this directory as a salt state collection and not a formula
[collection_name](#collection_name) | | used to derive then name of states we want to apply in a state collection. (if collection_name isn't set, formula will be used)
[pillars](#pillars)| {} | pillar data
[pillars-from-files](#pillars-from-files) | | a list of key-value pairs for files that should be loaded as pillar data
[grains](#grains) | | a hash to be re-written as /etc/salt/grains on the guest
[dependencies](#dependencies) | [] | a list of hashes specifying dependencies formulas to be copied into the VM. e.g. [{ :path => 'deps/icinga-formula', :name => 'icinga' }]
[vendor_path](#vendor_path) |""| path (absolute or relative) to a collection of formula reuired to be copied to the guest
[vendor_repo](#vendor_repo) |""| Setup DEB, RPM, SPM repository with hosted formulas
[init_environment](#init_environment) |""| commands to run to prior salt-call run


## Configuring Provisioner Options
The provisioner can be configured globally or per suite, global settings act as defaults for all suites, you can then customise per suite, for example:

    ---
    driver:
      name: vagrant

    provisioner:
      name: salt_solo
      formula: beaver
      pillars:
      state_top:
        base:
          '*':
            - beaver
            - beaver.ppa

    platforms:
      - name: ubuntu-12.04

    suites:
      - name: default

      - name: default_2016112
        provisioner:
          salt_version: 2016.11.2
          salt_install: apt

          - name: tcp-output
            provisioner:
              pillars:
                top.sls:
                  base:
                    '*':
                      - beaver
                beaver.sls:
                  beaver:
                    transport: tcp

in this example, the default suite will install salt via the bootstrap method, meaning that it will get the latest package available for the platform via the [bootstrap shell script](https://bootstrap.saltstack.org). We then define another suite called `default_2016112`, this has the provisioner install salt-2016.11.2 via apt-get (this defaults to using Ubuntu repository, which you can override by setting `salt_apt_repo` and `salt_apt_key` based on information provided in [SaltStack Package Repository page](https://repo.saltstack.com/).

### [formula](id:formula)
When running in normal mode, this must be set to the name of the formula your testing, this name is used to derive the name of the directory that should copied down to the guest.

For a project layout like this:

    .kitchen.yml
    beaver/init.sls
    beaver/foo.sls

formula should be set to ```beaver```


If you want all files & directories copied down to the host, see the [is_file_root](#is_file_root) option.
### [is_file_root](id:is_file_root)
Setting the ```is_file_root``` flag allows you to work with a directory tree that more closely resembles a built file_root on a salt-master, where you have may have multiple directories of states or formula.  The project is recursively copied down to guest instance, excluding any hidden files or directories (i.e. .git is not copied down, this is the standard behaviour of ruby's FileUtil.cp_r method)

Consider a directory that looks like this:

    top.sls
    .kitchen.yml
    apache/init.sls
    mysql/init.sls
    mysql/client.sls
    mysql/server.sls
    php/init.sls
    ...

With a .kitchen.yml like this you can now test the completed collection:

    ---
    driver:
      name: vagrant

    provisioner:
      name: salt_solo
      is_file_root: true
      state_top:
        base:
          '*':
            - apache
            - mysql.client

    platforms:
      - name: ubuntu-12.04

    suites:
      - name: default

In this example, the apache state could use functionality from the php state etc.  You're not just restricted to a single formula.

### [salt_install](id:salt_install)

Choose your method to install SaltStack :

* **bootstrap :** install SaltStack from bootstrap script (see: [salt_bootstrap_url](id:salt_bootstrap_url))
* **apt :** install SaltStack from specified repository (see: [salt_apt_repo](id:salt_apt_repo))
* **ppa :** install SaltStack from ppa repository (see: [salt_ppa](id:salt_ppa))
* **distrib :** install SaltStack from distribution repositories

### [salt_bootstrap_options](id:salt_bootstrap_options)
Options to pass to the salt bootstrap installer.  For example, you could choose to install salt from the develop branch like this:

    suites:
      - name: use-development-branch-salt
        provisioner:
          salt_bootstrap_options: -M -N git develop

Details on the various options available at the [salt-bootstrap](https://github.com/saltstack/salt-bootstrap/blob/develop/bootstrap-salt.sh#L180) documentation.

### [salt_copy_filter](id:salt_copy_filter)
When kitchen copies states, formula & pillars down to the guests it creates to execute the states & run tests against, you can filter out paths that you don't want copied down.  The copy is conducted by ruby's FileUtils.cp method, so all hidden directories are skipped (e.g. ```.git```, ```.kitchen``` etc).

You can supply a list of paths or files to skip by setting an array in the provisioner block:


    suites:
      - name: copy_filter_example
        provisioner:
          salt_copy_filter:
            - somefilenametoskip
            - adirectorythatshouldbeskipped




### [salt_version](id:salt_version)
Version of salt to install, via the git bootstrap method, unless ```salt_install``` is set to ```apt```, in which case the version number is used to generate the package name requested via apt

### [salt_apt_repo](id:salt_apt_repo)
### [salt_apt_repo_key](id:salt_apt_repo_key)
### [salt_ppa](id:salt_ppa)
Adds the supplied PPA. The default being the Official SaltStack PPA. Useful when the release (e.g. vivid) does not have support via the standard boostrap script or apt repo.

### [chef_bootstrap_url](id:chef_bootstrap_url)
### [salt_config](id:salt_config)
### [salt_minion_config](id:salt_minion_config)
### [salt_file_root](id:salt_file_root)
### [salt_pillar_root](id:salt_pillar_root)
### [salt_state_top](id:salt_state_top)
### [salt_run_highstate](id:salt_run_highstate)
### [state_top](id:state_top)
The states to be applied, this is rendered into top.sls in the guest, you can define a different state_top for each suite to test different states that may clash

    suites:
      - name: client
        provisioner:
        state_top:
          base:
            '*':
              - beaver
              - beaver.ppa

      - name: server
        provisioner:
        state_top:
          base:
            '*':
              - beaver.server
              - beaver.ppa

### [state_top_from_file](id:state_top_from_file)
Instead of rendering ```top.sls``` on the guest from the definition in .kitchen.yml, use top.sls found in the repo.

    suites:
      - name: use-top-from-disk
        provisioner:
          state_top_from_file: true


### [state_collection](id:state_collection)
Setting the ```state_collection``` flag to true makes kitchen-salt assume that the state files are at the same level as the ```.kitchen.yml```, unlike a formula, where the states are in a directory underneath the directory containing ```.kitchen.yml```.  When using ```state_collection:true```, you must also set the [collection_name](#collection_name).

### [collection_name](id:collection_name)
When dealing with a collection of states, it's necessary to set the primary collection name, so that when we call salt-call in the guest, the states have been put into directory that matches the name referenced in the state_top, for example, consider this simple logrotate state collection:

    -rw-r--r--+  1 simonm  staff    479 20 May 01:12 .kitchen.yml
    -rw-r--r--+  1 simonm  staff    655 18 Mar 16:08 init.sls
    drwxr-xr-x+  3 simonm  staff    102 20 May 00:19 test

.kitchen.yml looks like this:

    ---
    driver:
      name: vagrant

    provisioner:
      name: salt_solo
      state_collection: true
      collection_name: logrotate
      state_top:
        base:
          '*':
            - logrotate

    platforms:
      - name: ubuntu-12.04

    suites:
      - name: default

In order for salt-call to be able to find the logrotate state and apply init.sls, the path to init.sls must be logrotate/init.sls, relative to a ```file_roots``` entry.

### [pillars](id:pillars)

define the pillars you want supplied to salt, you must define top.sls so that any subsequent pillars are loaded:

      pillars:
        top.sls:
          base:
            '*':
              - beaver
        beaver.sls:
          beaver:
            transport: tcp

### [pillars-from-files](id:pillars-from-files)
The pillars-from-files option allows you to load pillar data from an external file, instead of being embedded in the .kitchen.yml.  This allows you to re-use the example files or reduce the clutter in your .kitchen.yml

Consider the following suite definition:

      - name: tcp-output-external-pillar
        provisioner:
          pillars-from-files:
            beaver.sls: pillar.example
          pillars:
            top.sls:
              base:
                '*':
                  - beaver


And the contents of pillar.example is a normal pillar file:

        $ cat pillar.example
        # defaults are set in map.jinja and can be over-ridden like this
        beaver:
          transport: stdout
          format: json



### [grains](id:grains)
(since v0.0.15)

This options allows you to set grains on the guest, they are written out to ``/etc/salt/grains``

For example, the following suite will define grains on the guest:

      - name: set-grains-test
        provisioner:
          salt_version: 0.16.2
          grains:
            roles:
              - webserver
              - memcache
            deployment: datacenter4
            cabinet: 13
            cab_u: 14-15

### [dependencies](id:dependencies)

Specify formula dependencies:

  provisioner:
    dependencies:
      - name: foo
        path: ../formulas/foo
      - name: linux
        repo: apt
        package: salt-formula-linux
      - name: nginx
        repo: git
        source: https://github.com/salt-formulas/salt-formula-nginx.git


### [vendor_path](id:vendor_path)

Path to your local formulas:

  provisioner:
    vendor_path: ./srv/env/dev/_formulas


### [vendor_repo](id:vendor_repo)

In order to configure APT, YUM, SPM repositories for kitchen run.
Example:

  provisioner:
    vendor_repo:
      - type: apt
        url: http://apt.tcpcloud.eu/nightly
        key_url: http://apt.tcpcloud.eu/public.gpg
        components: main tcp-salt


### [init_environment](id:init_environment)

In order to execute additional commands before salt-call run.
Example, setup reclass:

  provisioner:
    init_environment: |
      mkdir -p $SALT_ROOT/reclass/classes
      ln -fs /usr/share/salt-formulas/reclass/* $SALT_ROOT/reclass/
      find /usr/share/salt-formulas/env/_formulas -name metadata -type d | xargs -I'{}' \
        ln -fs {}/service $SALT_ROOT/reclass/classes/

