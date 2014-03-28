# kitchen-salt provisioner configuration

The provisioner block is used to select & configure many aspects of the provisioner being used by test-kitchen, the following options are supported by kitchen-salt:

* name
* formula
* salt_version
* salt_install
* salt_bootstrap_url
* salt_bootstrap_options
* salt_apt_repo
* salt_apt_repo_key
* chef_bootstrap_url
* salt_config
* salt_minion_config
* salt_file_root
* salt_pillar_root
* salt_state_top
* salt_run_highstate
* state_collection
* state_top
* pillars
* pillars-from-files

### pillars

define the pillars you want supplied to salt, you must define top.sls so that any subsequent pillars are loaded:

      pillars:
        top.sls:
          base:
            '*':
              - beaver
        beaver.sls:
          beaver:
            transport: tcp

### pillars-from-files

This options allows you to load a pillar yaml file from disk, instead of it having to be declared in full in .kitchen.yml, this also allows you to re-use any pillar.example files you are distributing with your formula:

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


## Global and per-suite configuration
The kitchen-salt provisioner can be configured either globally or on a per suite basis, the same as any other test-kitchen provisioner.  
	
	provisioner:
	  name: salt_solo
	  formula: beaver
	  
	suites:
	  - name: default
	    provisioner:
	      pillars:
	        top.sls:
	          base:
	            '*':
	              - beaver
	        beaver.sls:
	          beaver:
	            transport: tcp
	      state_top:
	        base:
	          '*':
	            - beaver
	            - beaver.ppa


# Catching salt failures
Catching salt failures is particularly troublesome, as salt & salt-call don't do a very good job of setting the exit code to something useful, around ~0.17.5, the `--retcode-passthrough` option was added, but even in 2014.1.0 this is still flawed, [PR11337](https://github.com/saltstack/salt/pull/11337) should help fix some of those problems.  In the mean time, we scan the salt-call output for signs of failure (`grep -e Result.*False` bascially) and check for a non-zero exit code from salt-call.