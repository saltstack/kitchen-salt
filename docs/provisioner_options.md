<!--
# @markup markdown
# @title Provisioner Options
# @author SaltStack Inc.
-->

# Provisioner Options #

## State Options ##

### dry_run ###

default: `false`

Setting this to True will run the highstate with test=True (good for testing states syntax)

### formula ###

default: `nil`

Name of the formula directory for finding where the state files are located.

### is_file_root ###

default: `false`

Treat the root directory of this project as a complete file root.

Setting the `is_file_root` flag allows you to work with a directory tree that more closely resembles a built file_root on a salt-master, where you have may have multiple directories of states or formula.  The project is recursively copied down to guest instance, excluding any hidden files or directories (i.e. .git is not copied down, this is the standard behaviour of ruby's FileUtil.cp_r method)

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

### local_salt_root ###

default: `nil`

When used with is_file_root, the directory specified here represents the /srv/ directory and everything will be copied there.

    provisioner:
      is_file_root: true
      local_salt_root: setup/

The above will require that a `salt` directory be located at `setup/salt/` with all the state files in it.  To use the root directory, set `local_salt_root: '.'`.

### remote_states ###

default: `nil`

This is used for testing environments.  Specify the salt states elsewhere, and then use them to deploy code from the current environment.

    ---
    provisioner:
      name: salt_solo
      remote_states:
        repo: git
        name: git://github.com/saltstack/salt-jenkins.git
        branch: 2017.7
        testingdir: /testing
      state_top:
        base:
          '*':
            - git.salt

This will clone down the git repo to the sandbox /srv/salt, and then run the git.salt state.

Salt-Jenkins is used to configure the testing environment for saltstack.

The repo from which this is run is copied with the `salt_copy_filter` applied to the `testingdir`

### log_level ###

default: `nil`

The log level with which the salt-call command will be run.

## Grain and Pillar Options

### grains ###

default: `nil`

This options allows grains to be set on the guest, written out to ``/etc/salt/grains``

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

### pillars ###

default: `{}`

Dictionary of pillar files to setup on the minion.

    pillars:
      top.sls:
        base:
          '*':
            - testing
      testing.sls:
        python:
          bin: /usr/bin/python3
          version: 3

### pillars-from-files ###

default: `nil`

The pillars-from-files option allows for loading pillar data from another file, instead of being embedded in the .kitchen.yml.  This allows the re-use of the example files or reduce the clutter in .kitchen.yml

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

    # defaults are set in map.jinja and can be over-ridden like this
    beaver:
      transport: stdout
      format: json

### pillars_from_directories ###

default: `[]`

A list of directories that will be copied recursively to the pillar root.

## Install Salt ##

### salt_install ###

default: `bootstrap`

Method by which salt will be installed:

- **bootstrap**: install salt with the bootstrap script.
- **yum**: install salt from a yum repository.
- **apt**: install salt from an apt repository.
- **distrib**: install the version of salt that comes with the distribution.
- **ppa**: install salt from a ppa.

Except for `distrib` and `bootstrap`, most of these options will require extra configuration to make sure it fits the tests distribution version.  Unless the newest version is used, then it should just work for yum and apt setups.

### salt_version ###

default: `latest`

The desired version of salt that will be installed.  For some places, this is used to set the repo to enable or what version to pass to bootstrap.

This is also used to verify that the correct version of salt was installed before running the highstate.

### salt_bootstrap_url ###

default: `https://bootstrap.saltstack.com`

Location of the bootstrap script.

For Windows, use the [powershell script](https://github.com/saltstack/salt-bootstrap/blob/develop/bootstrap-salt.ps1)

### salt_bootstrap_options ###

default: `nil`

Optional options passed to the bootstrap script.  By default this gets set to the `salt_version` if nothing is specified here.

For example, this could be used to install salt from the develop branch:

    suites:
      - name: use-development-branch-salt
        provisioner:
          salt_bootstrap_options: -M -N git develop

Details on the various options available at the [salt-bootstrap](https://docs.saltstack.com/en/latest/topics/tutorials/salt_bootstrap.html) documentation.

For the Windows Powershell script:

    platform:
      - name: windows
        salt_bootstrap_script: https://github.com/saltstack/salt-bootstrap/blob/develop/bootstrap-salt.ps1
        salt_bootstrap_options: -version 2017.7.2

### salt_apt_repo ###

default: `https://repo.saltstack.com/apt/ubuntu/16.04/amd64/`
This should be the top level of the apt repository so that the `salt_version` can be appended to the url.

### salt_apt_repo_key ###

default: `https://repo.saltstack.com/apt/ubuntu/16.04/amd64/latest/SALTSTACK-GPG-KEY.pub`

The location of the apt repo key.

### salt_ppa ###

default: `ppa:saltstack/salt`

Specify the ppa to enable for installing.  This is probably not as useful anymore now that salt is managed from the [official repos](https://repo.saltstack.com/#ubuntu)

### salt_yum_rpm_key ###

default: `https://repo.saltstack.com/yum/redhat/7/x86_64/archive/%s/SALTSTACK-GPG-KEY.pub`

The rpm key that should be installed for verifying signatures of the yum repo packages.

### salt_yum_repo ###

default: `https://repo.saltstack.com/yum/redhat/$releasever/$basearch/archive/%s`

The baseurl for the yum repository.  `%s` is replaced with `salt_version`. More information on [SaltStack Package Repo](https://repo.saltstack.com/)

### salt_yum_repo_key ###

default: `https://repo.saltstack.com/yum/redhat/$releasever/$basearch/archive/%s/SALTSTACK-GPG-KEY.pub`

The gpg key url to the key for the yum repository file. `%s` is replaced with `salt_version`. More information on [SaltStack Package Repo](https://repo.saltstack.com/)

### salt_yum_repo_latest ###

default : `https://repo.saltstack.com/yum/redhat/salt-repo-latest-2.el7.noarch.rpm`

The url for the yum repository rpm. Used to install if `salt_version` is `latest`. More information on [SaltStack Package Repo](https://repo.saltstack.com/)

### pip_pkg ###

default: `salt==%s`

Name of the pip package to install for salt.  This can be a file location or a package name from a pypi simple server.

### pip_editable ###

default: `false`

Install using the editable flag for pip

### pip_index_url ###

default: `https://pypi.python.org/simple/`

Path to the pypi simple index to use for installing salt.

### pip_extra_index_url ###

default: `[]`

List of extra index urls to fall back to if dependencies are not found on the main index.

### pip_bin ###

default: `pip`

pip binary in the `$PATH` or path to a pip binary to use for installing salt.

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
salt_force_color| false |
[state_top](#state_top)| {} | states that should be applied, in standard top.sls format
[state_top_from_file](#state_top_from_file) | false |
state_collection | false | treat this directory as a salt state collection and not a formula
[collection_name](#collection_name) | | used to derive then name of states we want to apply in a state collection. (if collection_name isn't set, formula will be used)
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

& ###
When running in normal mode, this must be set to the name of the formula your testing, this name is used to derive the name of the directory that should copied down to the guest.

For a project layout like this:

    .kitchen.yml
    beaver/init.sls
    beaver/foo.sls

formula should be set to ```beaver```


If you want all files & directories copied down to the host, see the [is_file_root](#is_file_root) option.
* **bootstrap :** install SaltStack from bootstrap script (see: [salt_bootstrap_url](id:salt_bootstrap_url))
* **apt :** install SaltStack from specified repository (see: [salt_apt_repo](id:salt_apt_repo))
* **ppa :** install SaltStack from ppa repository (see: [salt_ppa](id:salt_ppa))
* **distrib :** install SaltStack from distribution repositories
* **yum :** install SaltStack from yum repository for RHEL based systems

& ###
Options to pass to the salt bootstrap installer.  For example, you could choose to install salt from the develop branch like this:

    suites:
      - name: use-development-branch-salt
        provisioner:
          salt_bootstrap_options: -M -N git develop

Details on the various options available at the [salt-bootstrap](https://github.com/saltstack/salt-bootstrap/blob/develop/bootstrap-salt.sh#L180) documentation.

& ###
When kitchen copies states, formula & pillars down to the guests it creates to execute the states & run tests against, you can filter out paths that you don't want copied down.

You can supply a list of paths or files to skip by setting an array in the provisioner block:


    suites:
      - name: copy_filter_example
        provisioner:
          salt_copy_filter:
            - somefilenametoskip
            - adirectorythatshouldbeskipped

& ###
Version of salt to install. If [`salt_install`](#salt_install) is set to
anything other than `'bootstrap'` (default) then this value will be
injected into the configuration specific to that installation method.

& ###
& ###
& ###
Adds the supplied PPA. The default being the Official SaltStack PPA. Useful when the release (e.g. vivid) does not have support via the standard boostrap script or apt repo.

& ###
& ###
& ###
& ###
& ###
& ###
& ###
& ###
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

& ###
Instead of rendering ```top.sls``` on the guest from the definition in .kitchen.yml, use top.sls found in the repo.

    suites:
      - name: use-top-from-disk
        provisioner:
          state_top_from_file: true


& ###
Setting the ```state_collection``` flag to true makes kitchen-salt assume that the state files are at the same level as the ```.kitchen.yml```, unlike a formula, where the states are in a directory underneath the directory containing ```.kitchen.yml```.  When using ```state_collection:true```, you must also set the [collection_name](#collection_name).

& ###
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

& ###

define the pillars you want supplied to salt, you must define top.sls so that any subsequent pillars are loaded:

      pillars:
        top.sls:
          base:
            '*':
              - beaver
        beaver.sls:
          beaver:
            transport: tcp

& ###
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

& ###
The pillars_from_directories option allows you to copy directories recursively. It takes a list of hash which defines the source directory and the destination directory:

      - name: tcp-output-external-pillar
        provisioner:
          pillars_from_directories:
            - source: './test/fixtures'
              dest: /srv/saltconfig

**Note:** The destination directory is relative to the Kitchen temp dir (/tmp/kitchen)

& ###
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

& ###

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


& ###

Path to your local formulas:

    provisioner:
      vendor_path: ./srv/env/dev/_formulas


& ###

In order to configure APT, YUM, SPM repositories for kitchen run.
Example:

    provisioner:
      vendor_repo:
        - type: apt
          url: http://apt.tcpcloud.eu/nightly
          key_url: http://apt.tcpcloud.eu/public.gpg
          components: main tcp-salt


& ###

In order to execute additional commands before salt-call run.
Example, setup reclass:

    provisioner:
      init_environment: |
        mkdir -p $SALT_ROOT/reclass/classes
        ln -fs /usr/share/salt-formulas/reclass/* $SALT_ROOT/reclass/
        find /usr/share/salt-formulas/env/_formulas -name metadata -type d | xargs -I'{}' \
          ln -fs {}/service $SALT_ROOT/reclass/classes/

