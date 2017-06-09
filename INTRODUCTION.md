I'd like to introduce you to something I've been working on over the last few days, I finally scratched an itch and wrote a salt provisioner for test-kitchen.  If you've arrived at salt via the chef community, you'll likely have heard of test-kitchen, an awesome tool by Fletcher Nichol (fnichol) that makes it very simple to perform a suite of tests against a cookbook, by converging on a virtual machine, it supports executing different suites of tests & multiple guest platforms (various version & flavours of Ubuntu, CentOS, FreeBSD etc).

[Test Kitchen](http://kitchen.ci/) describes itself as "a test harness tool to execute your configured code on one or more platforms", through it's modular architecture, I was able to build a working salt provider in a few hours, this is [kitchen-salt](https://github.com/saltstack/kitchen-salt). There is lots more info about Test Kitchen on their website, including a very useful tutorial on creating a Chef Cookbook and then adding some Test Kitchen love, I suggest you read through this to get a feel for what possible & what I'm trying to achieve here.

##Installation
Test Kitchen is packaged as a RubyGem, and so is kitchen-salt, so we need a working Ruby 1.9 environment, and some supporting bits, like somewhere to create virtual machines etc, in this example we're going to use Vagrant & VirtualBox, in fact pretty much everything they have in the [Test Kitchen Installing](http://kitchen.ci/docs/getting-started/installing) step.

kitchen-salt depends on test-kitchen-1.2.1, which is a standard ruby gem, the easiest way to get that into a usable environment is to use bundler, which we'll show below. The curl command (pulling down [https://gist.github.com/simonmcc/8564612](https://gist.github.com/simonmcc/8564612) is just a Gemfile that bundler will use to install the correct rubygems). I like keeping my Ruby environments self contained using RVM, (it's quite like Python's virtualenv, if you ignore the fact that it compiles stuff :/), so we'll create an environment with the right bits to get us started:

    $ mkdir kitchen-salt-tutorial
    $ cd kitchen-salt-tutorial
    $ rvm --create --ruby-version use 1.9.3@kitchen-salt-tutorial
    $ curl https://gist.githubusercontent.com/simonmcc/8564612/raw/50aa21f2a52ca554e4afb50a44b0903f415113eb/- > Gemfile
    $ bundle install

    ## we can now check that we have a working kitchen executable
    $ kitchen help

So now what?  Well, we need to get a copy of a salt formula in our workspace and add some bits to tell Test Kitchen what to do, let's start by cloning down a simple formula, in this case, beaver-formula, a nice logstash log shipper:

    $ git clone https://github.com/simonmcc/beaver-formula.git
    $ cd beaver-formula

Now what?  well, Test Kitchen keeps it's primary config in `.kitchen.yml`, we use this to tell it some usefull bits, like what platforms we want to test, this is a simple YAML file, put this in your `beaver-formula/.kitchen.yml`

	---
	driver:
	  name: vagrant

	platforms:
	  - name: ubuntu-12.04

	provisioner:
	  name: salt_solo
	  formula: beaver
      state_top:
        base:
          '*':
            - beaver
            - beaver.ppa

	suites:
	  - name: default
	    
The `driver` section tells Test Kitchen what we're going to use for creating our guest VM's to test in, `platforms` are the  different guest operating systems we'll test against, `provisioner` is details about the provisioner to be used, in this case our kitchen-salt gem provides a provisioner called `salt_solo`, we also set some defaults for provisioner.  `suites` are a collection of attributes & tests to be run in conjunction, in this instance we're not setting any specific attributes, so we'll inherit the ones set in the `provisioner` block.

Right now we have enough to see if the formula will converge on it's own without any pillar data, so let's do it, this will possibly take a few minutes as Vagrant will download the box as required, and then kitchen-salt will install salt & few other bits in the guest vm before running salt:

    $ kitchen test
    -----> Starting Kitchen (v1.1.2.dev)
    -----> Cleaning up any prior instances of <default-ubuntu-1204>
    -----> Destroying <default-ubuntu-1204>...
           Finished destroying <default-ubuntu-1204> (0m0.00s).
    -----> Testing <default-ubuntu-1204>
    -----> Creating <default-ubuntu-1204>...
           Bringing machine 'default' up with 'virtualbox' provider...
           [default] Importing base box 'opscode-ubuntu-12.04'...
           [default] Matching MAC address for NAT networking...
           [default] Setting the name of the VM...
           [default] Clearing any previously set forwarded ports...
           [default] Fixed port collision for 22 => 2222. Now on port 2201.
           [default] Clearing any previously set network interfaces...
           [default] Preparing network interfaces based on configuration...
           [default] Forwarding ports...
           [default] -- 22 => 2201 (adapter 1)
           [default] Running 'pre-boot' VM customizations...
           [default] Booting VM...
           
This is the start of Test Kitchen doing it's thing, it's creating an environment to execute our formula in, the kitchen-salt provisioner will then make sure salt is installed, and that we have enough working ruby for busser to work, let's skip to the end of the output:
    
           ----------
               State: - file
               Name:      /etc/beaver.conf
               Function:  managed
            Result:    True
            Comment:   File /etc/beaver.conf updated
                   Changes:   diff: ---
           +++
           @@ -1,2 +1,10 @@
           +# Managed by Salt.
            [beaver]
           -files: /var/log/syslog,/var/log/*.log+
           +transport: stdout
           +format: raw
           +logstash_version: 0
           +sincedb_path: /var/cache/beaver/sincedb.sqlite
           +
           +# Monitored Files:
           +
    
                       mode: 644
    
           ----------
               State: - file
               Name:      /var/cache/beaver
               Function:  directory
            Result:    True
            Comment:   Directory /var/cache/beaver updated
                   Changes:   /var/cache/beaver: New Dir
    
           ----------
               State: - service
               Name:      beaver
               Function:  running
            Result:    True
            Comment:   Started Service beaver
                   Changes:   beaver: True
    
    
           Summary
           ------------
           Succeeded: 5
           Failed:    0
           ------------
           Total:     5
           Finished converging <default-ubuntu-1204> (1m25.31s).
    -----> Setting up <default-ubuntu-1204>...
           Finished setting up <default-ubuntu-1204> (0m0.00s).
    -----> Verifying <default-ubuntu-1204>...
           Finished verifying <default-ubuntu-1204> (0m0.00s).
    -----> Destroying <default-ubuntu-1204>...
           [default] Forcing shutdown of VM...
           [default] Destroying VM and associated drives...
           Vagrant instance <default-ubuntu-1204> destroyed.
           Finished destroying <default-ubuntu-1204> (0m3.47s).
           Finished testing <default-ubuntu-1204> (2m6.00s).
    -----> Kitchen is finished. (2m6.56s)

So, we can see that `salt-call` executed our state(s) successfully, in 2m6.56s, all we know is that salt-call completed successfully, which is a great start.

But we can do better than that, much better. Test Kitchen support a number of testing frameworks, bats, serverspec and a few more.  We're going to add some simple tests to further validate our formula, lets start with the simplest, bats.

First of call, we need somewhere to put our tests, test-kitchen defaults to storing tests in `test/integration/`, tests are grouped by suite, so our first test should be in `test/integration/default`, they are then grouped by the test framework, so the full path for our first bats test is `test/integration/bats`.  Lets create a simple bats test:

    $ mkdir -p test/integration/default/bats
    $ cat > test/integration/default/bats/beaver_installed.bats <<TEST
    #!/usr/bin/env bats
    
    @test "beaver binary is found in PATH" {
      run which beaver
      [ "\$status" -eq 0 ]
    }
    TEST
    $
    
And now we'll re-run the `kitchen test`, as this generates a lot of output while installing salt and various other bits, only the last few interesting lines are shown below:
	
	       Finished converging <default-ubuntu-1204> (5m32.64s).
	-----> Setting up <default-ubuntu-1204>...
	Fetching: thor-0.18.1.gem (100%)
	Fetching: busser-0.6.0.gem (100%)
	Successfully installed thor-0.18.1
	Successfully installed busser-0.6.0
	2 gems installed
	-----> Setting up Busser
	       Creating BUSSER_ROOT in /tmp/busser
	       Creating busser binstub
	       Plugin bats installed (version 0.1.0)
	-----> Running postinstall for bats plugin
	      create  /tmp/bats20140124-2927-12zodae/bats
	      create  /tmp/bats20140124-2927-12zodae/bats.tar.gz
	Installed Bats to /tmp/busser/vendor/bats/bin/bats
	      remove  /tmp/bats20140124-2927-12zodae
	       Finished setting up <default-ubuntu-1204> (0m23.23s).
	-----> Verifying <default-ubuntu-1204>...
	       Suite path directory /tmp/busser/suites does not exist, skipping.
	Uploading /tmp/busser/suites/bats/beaver_installed.bats (mode=0644)
	-----> Running bats test suite
	 ✓ beaver binary is found in PATH
	
	1 test, 0 failures
	       Finished verifying <default-ubuntu-1204> (0m1.36s).
	-----> Destroying <default-ubuntu-1204>...
	       [default] Forcing shutdown of VM...
	       [default] Destroying VM and associated drives...
	       Vagrant instance <default-ubuntu-1204> destroyed.
	       Finished destroying <default-ubuntu-1204> (0m4.88s).
	       Finished testing <default-ubuntu-1204> (6m55.08s).
	-----> Kitchen is finished. (6m56.01s)

The first section is Test Kitchen setting up the test frameworks for you (thor, busser, Bats), the last section:

	-----> Running bats test suite
	 ✓ beaver binary is found in PATH
	
	1 test, 0 failures
	       Finished verifying <default-ubuntu-1204> (0m1.36s).
	-----> Destroying <default-ubuntu-1204>...
	       [default] Forcing shutdown of VM...
	       [default] Destroying VM and associated drives...
	       Vagrant instance <default-ubuntu-1204> destroyed.
	       Finished destroying <default-ubuntu-1204> (0m4.88s).
	       Finished testing <default-ubuntu-1204> (6m55.08s).
	-----> Kitchen is finished. (6m56.01s)

is the really interesting bit, we just verified that the beaver binary was installed.

Bats is a little bit crude and relies on you knowing various things about your platform, in this instance, Ubuntu 12.04.  One of the other supported test frameworks is [serverspec](http://serverspec.org/). serverspec is a much more complete testing toolkit, allowing youto abstract your tests & let serverspec handle the platform specific bits.

Lets add a more complete serverspec test suite:

    $ mkdir -p test/integration/default/serverspec
    $ curl https://gist.github.com/simonmcc/8589713/raw/a2f52f3cfe2dbb00082999fe518709e114069a38/beaver_spec.rb > test/integration/default/serverspec/beaver_spec.rb
    $ cat test/integration/default/serverspec/beaver_spec.rb
    require 'serverspec'
	
	include Serverspec::Helper::Exec
	include Serverspec::Helper::DetectOS
	
	RSpec.configure do |c|
	  c.before :all do
	    c.path = '/sbin:/usr/sbin'
	  end
	end
	
	describe "beaver log shipper" do
	
	  it "has a running service of beaver" do
	    expect(service("beaver")).to be_running
	  end
	
	  describe service('beaver') do
	      it { should be_enabled   }
	      it { should be_running   }
	  end
	
	  describe file('/etc/beaver.conf') do
	      it { should be_file }
	      it { should be_owned_by 'root' }
	      it { should contain "transport: stdout" }
	  end
	
	  describe file('/var/cache/beaver') do
	    it { should be_directory }
	    it { should be_owned_by 'root' }
	    it { should be_grouped_into 'root' }
	    it { should be_mode 750 }
	  end
	
	end
	
So, with serverspec you describe a set of features that your server should comply with, it's a fairly easy to understand notation.  Let's re-run our tests (via `kitchen verify`) and look at the results:
	
	$ kitchen verify
	-----> Starting Kitchen (v1.1.2.dev)
	-----> Verifying <default-ubuntu-1204>...
	       Removing /tmp/busser/suites/bats
	       Removing /tmp/busser/suites/serverspec
	Uploading /tmp/busser/suites/bats/beaver_installed.bats (mode=0644)
	Uploading /tmp/busser/suites/serverspec/beaver_spec.rb (mode=0644)
	-----> Running bats test suite
	 ✓ beaver binary is found in PATH
	
	1 test, 0 failures
	-----> Running serverspec test suite
	/opt/chef/embedded/bin/ruby -I/tmp/busser/suites/serverspec -S /opt/chef/embedded/bin/rspec /tmp/busser/suites/serverspec/beaver_spec.rb --color --format documentation
	
	beaver log shipper
	  has a running service of beaver
	  Service "beaver"
	    should be enabled
	    should be running
	         File "/etc/beaver.conf"
	
	    should be file
	    should be owned by "root"
	    should contain "transport: stdout"
	  File "/var/cache/beaver"
	    should be directory
	    should be owned by "root"
	    should be grouped into "root"
	    should be mode 750
	
	Finished in 0.14824 seconds
	10 examples, 0 failures
	       Finished verifying <default-ubuntu-1204> (0m2.71s).
	-----> Kitchen is finished. (0m3.79s)
	
So now we've verified that the service is running, that the files are owned by who we expect, that the config file contains fragments we're interested in. Awesome.