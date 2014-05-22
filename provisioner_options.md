
# Provisioner Options

key | default value | Notes
----|---------------|--------
formula | | name of the formula, used to derive the path we need to copy to the guest
salt_install| "bootstrap" | Method by which to install salt, "bootstrap" or "apt"
salt_bootstrap_url | "http://bootstrap.saltstack.org" | location of bootstrap script
[salt_bootstrap_options](#salt_bootstrap_options) | | optional options passed to the salt bootstrap script
salt_version | "0.16.2"| desired version, only affects apt installs
salt_apt_repo | "http://apt.mccartney.ie"| apt repo
salt_apt_repo_key| "http://apt.mccartney.ie/KEY"| apt repo key
chef_bootstrap_url| "https://www.getchef.com/chef/install.sh"| the chef bootstrap installer, used to provide Ruby for the serverspec test runner on the guest OS
salt_config| "/etc/salt"|
salt_minion_config| "/etc/salt/minion"|
salt_file_root| "/srv/salt"|
salt_pillar_root| "/srv/pillar"|
salt_state_top| "/srv/salt/top.sls"|
salt_run_highstate| true |
state_top| {} | states that should be applied, in standard top.sls format
state_collection | false | treat this directory as a salt state collection and not a formula
[collection_name](#collection_name) | | used to derive then name of states we want to apply in a state collection. (if collection_name isn't set, formula will be used)
[pillars](#pillars)| {} | pillar data
[pillars-from-files](#pillars-from-files) | | a list of key-value pairs for files that should be loaded as pillar data
[grains](#grains) | | a hash to be re-written as /etc/salt/grains on the guest


##Configuring Provisioner Options
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

      - name: default_0162
        provisioner:
          salt_version: 0.16.2
          salt_install: apt

in this example, the default suite will install salt via the bootstrap method, meaning that it will get the latest package available for the platform via the [bootstrap shell script](http://bootstrap.saltstack.org). We then define another suite called `default_0162`, this has the provisioner install salt-0.16.2 via apt-get (this defaults to a mini repo of mine, which you can override, my repo only contains 0.16.2)

### [formula](id:formula)
### [salt_install](id:salt_install)
### [salt_bootstrap_options](id:salt_bootstrap_options) 
Options to pass to the salt bootstrap installer.  For example, you could choose to install salt from the develop branch like this:

    suites:
      - name: use-development-branch-salt
        provisioner:
          salt_bootstrap_options: -M -N git develop

Details on the various options available at the [salt-bootstrap](https://github.com/saltstack/salt-bootstrap/blob/develop/bootstrap-salt.sh#L180) documentation. 

### [salt_version](id:salt_version)
Version of salt to install, via the git bootstrap method, unless ```salt_install``` is set to ```apt```, in which case the version number is used to generate the package name requested via apt

### [salt_apt_repo](id:salt_apt_repo) 
### [salt_apt_repo_key](id:salt_apt_repo_key)
### [chef_bootstrap_url](id:chef_bootstrap_url)
### [salt_config](id:salt_config)
### [salt_minion_config](id:salt_minion_config)
### [salt_file_root](id:salt_file_root)
### [salt_pillar_root](id:salt_pillar_root)
### [salt_state_top](id:salt_state_top)
### [salt_run_highstate](id:salt_run_highstate)
### [state_top](id:state_top)
### [state_collection](id:state_collection)

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

### [pillars-from-files](id:pillars-from-files)
The pillars-from-files option allows you to load pillar data from an external file, instead of being embedded in the .kitchen.yml.  This allows you to re-use the example files or reduce the clutter in your .kitchen.yml

Consider the following suite definition:

      - name: tcp-output-external-pillar
        provisioner:
          pillars-from-files:
            beaver.sls: beaver-example.sls
          pillars:
            top.sls:
              base:
                '*':
                  - beaver

In this example, the beaver pillar is loaded from the example file in the repo, ``beaver-example.sls``, but we can still define the ``top.sls`` inline in the .kitchen.yml file.

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

