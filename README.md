# kitchen-salt
A Test Kitchen Provisioner for Salt

The provider works by generating a salt-minion config, creating pillars based on attributes in .kitchen.yml & calling salt-call.

This provider has been tested against the Ubuntu Cloud boxes running in vagrant/virtualbox.

## Requirements
You'll need a driver box that is supported by both the SaltStack [bootstrap](https://github.com/saltstack/salt-bootstrap) system & the Chef Omnibus installer (the Chef Omnibus installer is only needed to provide busser with a useable ruby environment, you can tell busser to use an alternative ruby if your box has suitable ruby support built in).

kitchen-salt has only been tested against Ubuntu 12.04 Cloud Images.

## Installation & Setup
You'll need the test-kitchen & kitchen-salt gem's installed in your system, along with kitchen-vagrant or some ther suitable driver for test-kitchen.

## Salt config in .kitchen.yml
Below is a working .kitchen.yml from one of our salt-formula

	---
	driver:
	  name: vagrant
	
	provisioner:
	  name: salt_solo
	  formula: beaver
	
	platforms:
	  - name: ubuntu-12.04-cloudimg
	    driver_config:
	      box: ubuntu-12.04-cloudimg
	      box_url: http://cloud-images.ubuntu.com/precise/current/precise-server-cloudimg-vagrant-amd64-disk1.box
	
	suites:
	  - name: default
	    attributes:
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
	            
Lets walk though that section at a time, the following section tells test-kitchen to use the kitchen-salt provider (salt_solo, maybe we'll get to a proper minion communicating with a salt-master at some point!), and that the formula we're testing is called beaver, this is used top copy the beaver formula to test box.

	provisioner:
	  name: salt_solo
	  formula: beaver
	  
The next section is standard test-kitchen stuff, just use a particular image for testing, in this case, Ubuntu 12.04 Cloud Images are what we use in production, so might as well test against them too!

	platforms:
	  - name: ubuntu-12.04-cloudimg
	    driver_config:
	      box: ubuntu-12.04-cloudimg
	      box_url: http://cloud-images.ubuntu.com/precise/current/precise-server-cloudimg-vagrant-amd64-disk1.box	  
	  
The next section is where things get kitchen-salt specific, the attributes hash is passed to the provisioner plugins, we use it to pass information down to the kitchen-salt code, in this instance we create 2 pillars, the default top.sls pillar, which references a beaver pillar, which we also supply.  We also declare the contents of state_top (we default to the top.sls on-disk, but you can override that should you need to)

	suites:
	  - name: default
	    attributes:
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