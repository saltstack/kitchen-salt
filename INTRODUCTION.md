I'd like to introduce you to something I've been working on over the last few days, I finally scratched an itch and wrote a salt provisioner for test-kitchen.  If you've arrived at salt via the chef community, you'll likely have heard of test-kitchen, an awesome tool by Fletcher Nichol (fnichol) that makes it very simple to perform a suite of tests against a cookbook, by converging on a virtual machine, it supports executing different suites of tests & multiple guest platforms (various version & flavours of Ubuntu, CentOS, FreeBSD etc).

[Test Kitchen](http://kitchen.ci/) describes itself as "a test harness tool to execute your configured code on one or more platforms", through it's modular architecture, I was able to build a working salt provider in a few hours, this is [kitchen-salt](https://github.com/simonmcc/kitchen-salt). There is lots more info about Test Kitchen on their website, including a very useful tutorial on creating a Chef Cookbook and then adding some Test Kitchen love, I suggest you read through this to get a feel for what possible & what I'm trying to achieve here.

##Installation
Test Kitchen is packaged as a RubyGem, and so is kitchen-salt, so we need a working Ruby 1.9 environment, and some supporting bits, like somewhere to create virtual machines etc, in this example we're going to use Vagrant & VirtualBox, infact pretty much everything they have in the [Test Kitchen Installing](http://kitchen.ci/docs/getting-started/installing) step.

I like keeping my Ruby environments self contained using RVM, (it's quite like Python's virtualenv, if you ignore the fact that it compiles stuff :/), so we'll create an environment with the right bits to get us started:

    $ mkdir kitchen-salt-tutorial
    $ cd kitchen-salt-tutorial
    $ rvm --create --ruby-version use 1.9.3@test-kitchen-tutorial
    $ gem install test-kitchen kitchen-vagrant kitchen-salt 
    
    ## we can now check that we have a working kitchen executable
    $ kitchen help
    
So now what?  Well, we need to get a copy of a salt formula in our workspace and add some bits to tell Test Kitchen what to do, let's start by cloning down a simple formula, in this case, beaver-formula, a nice logstash log shipper:

    $ git clone https://github.com/simonmcc/beaver-formula.git
    $ cd beaver-formula
     
Now what?  well, Test Kitchen keeps it's primary config in `.kitchen.yml`, we use this to tell it some usefull bits, like what platforms we want to test & where to get vagrant boxes (or other VM information if you are using some of the other drivers for ec2, OpenStack etc), this is a simple YAML file, put this in your `beaver-formula/.kitchen.yml`

	
	---
	driver:
	  name: vagrant
	
	platforms:
	  - name: ubuntu-12.04-cloudimg
	    driver_config:
	      box: ubuntu-12.04-cloudimg
	      box_url: http://cloud-images.ubuntu.com/precise/current/precise-server-cloudimg-vagrant-amd64-disk1.box
	
	provisioner:
	  name: salt_solo
	  formula: beaver
	
	suites:
	  - name: default
	    attributes:
	      state_top:
	        base:
	          '*':
	            - beaver
	            - beaver.ppa
    
The `driver` section tells Test Kitchen what we're going to use for creating our guest VM's to test in, `platforms` are the  different guest operating systems we'll test against, and `suites` are a collection of attributes & tests to be run in conjunction.

Right now we have enough to see if the formula will converge on it's own without any pillar data, so let's do it, this will possibly take a few minutes as Vagrant will download the box as required, and then kitchen-salt will install salt & few other bits in the guest vm before running salt:

	kitchen test
	-----> Starting Kitchen (v1.1.1)
	-----> Cleaning up any prior instances of <default-ubuntu-1204-cloudimg>
	-----> Destroying <default-ubuntu-1204-cloudimg>...
	       Finished destroying <default-ubuntu-1204-cloudimg> (0m0.00s).
	-----> Testing <default-ubuntu-1204-cloudimg>
	-----> Creating <default-ubuntu-1204-cloudimg>...
	       Bringing machine 'default' up with 'virtualbox' provider...
	       [default] Importing base box 'ubuntu-12.04-cloudimg'...
	       
This is the start of Test Kitchen doing it's thing, it's creating an environment to execute our formula in, the kitchen-salt provisioner will then make sure salt is installed, and that we have enough working ruby for busser to work, let's skip to the end of the output:

    INSERT TEST RESULTS ETC HERE
    
So, we can see that `salt-call` executed our state(s) successfully, now what? Test Kitchen support a number of testing frameworks, bats, serverspec and a few more