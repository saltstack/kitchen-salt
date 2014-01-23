
# Provisioner Options

key | default value | Notes
----|---------------|--------
salt_install| "bootstrap" | Method by which to install salt, "bootstrap" or "apt"
salt_bootstrap_url | "http://bootstrap.saltstack.org" | location of bootstrap script
salt_bootstrap_options | | optional options passed to the bootstrap script
salt_version | "0.16.2"| desired version, only affects apt installs
salt_apt_repo | "http://apt.mccartney.ie"| apt repo
salt_apt_repo_key| "http://apt.mccartney.ie/KEY"| apt repo key 
chef_bootstrap_url| "https://www.getchef.com/chef/install.sh"| the chef 
salt_config| "/etc/salt"|
salt_minion_config| "/etc/salt/minion"|
salt_file_root| "/srv/salt"|
salt_pillar_root| "/srv/pillar"|
salt_state_top| "/srv/salt/top.sls"|
pillars| {}|
state_top| {}|
salt_run_highstate| true|

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