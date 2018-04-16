<!--
# @markup markdown
# @title Setting up to run tests like Jenkins
# @author SaltStack Inc.
-->

# Setting up kitchen to run tests like Jenkins #

The new SaltStack Jenkins setup at https://jenkinsci.saltstack.com is using kitchen and the kitchen-ec2 driver to build servers for testing.

The only thing that needs to be available is `ruby` and `gem` or `bundler` (`gem install bundler`). The rest of this guide will be using bundler. If you need to install ruby, there is a guide available for managed versions using rbenv or rvm available in the {file:docs/gettingstarted.md} doc.

## Testing with Docker/Vagrant ##

By default, the salt `.kitchen.yml` is configured to use Docker to test Linux Distributions and Vagrant to test Windows.

Note: If `Vagrant` is installed on the system, the WinRM plugin will have to be installed in order to run any of the tests

    vagrant plugin install vagrant-winrm

`rsync` is also required.  The Salt test suite uses rsync to transfer files to the test instance, because symlinks must be maintained, and neither scp nor sftp preserve them.  With the base test suite in salt, kitchen-docker generates an ssh key at `.kitchen/docker_id_rsa`, this will need to be added to an ssh-agent.

    source <(ssh-agent)
    ssh-add .kitchen/docker_id_rsa

## Setting up EC2 ##

There are requirements that are needed to run tests in EC2.

1. An AWS account
1. A vpc/subnet needs to be created
1. A security group on that vpc that has port 22 and port 5985 open for connecting.
1. A private key

### AWS Account ###

An aws account will be required to build servers on EC2. The account will need `arn:aws:iam::aws:policy/AmazonEC2FullAccess` to be able to run all the necessary commands.  An API id/key will need to be exported in the environment in which the kitchen commands will be run in order to create the servers.

- AWS_ACCESS_KEY_ID
- AWS_SECRET_ACCESS_KEY

### VPC/Subnet setup ###

A subnet will need to be created.  There is not a specific requirement for the subnet, it just needs to be big enough to hold the number of test servers that is desired.

Since `associate_public_ip: true` is set in the kitchen driver, this subnet does not need to assign a public ip by default.

### Security Group setup ###

Make sure that the security group is attached to the vpc that is just created, and has the following ports open

- 22/tcp for connecting to Linux machines
- 5985/tcp for connecting to Windows machines

### Private Key setup ###

Make sure the private key is either created or uploaded to the same region that the VPC is created in.  Also make sure the private key is saved in a location that can be accessed and referenced on the machine where `kitchen` will be run.

## Setting up Kitchen ##

The first thing that needs to be done is setup the extra kitchen files.  The .kitchen.yml is templated to use files from .kitchen/ instead of the configurations in the actual file if the new files are available.  In order to build on EC2, you can either store the files in .kitchen/ inside of the git repository or export environment variables to point to new files.  The following files are the ones we use for Jenkins.

### .kitchen/driver.yml or SALT_KITCHEN_DRIVER ##

    driver:
      name: ec2
      associate_public_ip: true
      aws_ssh_key_id: <aws ssh key id>
      block_device_mappings:
      - device_name: /dev/sda1
        ebs:
          delete_on_termination: true
          volume_size: 30
          volume_type: gp2
      instance_type: t2.medium
      interface: public  # This can be set to "private" if you have everything setup to access it.
      region: <region>
      require_chef_omnibus: true
      security_group_ids:
      - <security group>
      spot_price: '0.04'
      subnet_id: <subnet id>
      tags:
        created-by: test-kitchen
    transport:
      name: rsync
      ssh_key: ~/.ssh/<aws key>.pem
      timeout: 30

This is the file that is being used for the ec2 driver.

The following fields will need to be filled out:

- aws_ssh_key_id -> This is the id of the public key that should be put on the VM
- ssh_key -> The path to the ssh key that goes with the aws_ssh_key_id.
- region -> This is the region that is setup to build servers in.
- security_group_ids -> This is the security group to be used, it needs to have port 22 open for linux and port 5985 for windows.
- subnet_id -> The subnet for the network interface that is going to be attached.

### .kitchen/platforms.yml or SALT_KITCHEN_PLATFORMS ###

    platforms:
    - name: opensuse
      driver:
        instance_type: t2.large
        spot_price: '0.04'
        image_search:
          owner-id: '679593333241'
          name: openSUSE-Leap-*-*-hvm-ssd-x86_64-*-ami-*
        tags:
          Name: kitchen-opensuse-<%= 10.times.map{[('a'..'z').to_a, (0..9).to_a].join[rand(36)]}.join %>
      transport:
        username: ec2-user
      provisioner:
        salt_bootstrap_options: -UX -p rsync git v<%= version %>
        salt_bootstrap_url: https://raw.githubusercontent.com/saltstack/salt-bootstrap/develop/bootstrap-salt.sh
    - name: centos-7
      driver:
        tags:
          Name: kitchen-centos-7-<%= 10.times.map{[('a'..'z').to_a, (0..9).to_a].join[rand(36)]}.join %>
    - name: centos-6
      driver:
        tags:
          Name: kitchen-centos-6-<%= 10.times.map{[('a'..'z').to_a, (0..9).to_a].join[rand(36)]}.join %>
      provisioner:
        salt_bootstrap_options: -P -p rsync -y -x python2.7 -X git v<%= version %> >/dev/null
    - name: fedora-26
      driver:
        tags:
          Name: kitchen-fedora-26-<%= 10.times.map{[('a'..'z').to_a, (0..9).to_a].join[rand(36)]}.join %>
      provisioner:
        salt_bootstrap_options: -X -p rsync git v<%= version %> >/dev/null
    - name: fedora-27
      driver:
        tags:
          Name: kitchen-fedora-27-<%= 10.times.map{[('a'..'z').to_a, (0..9).to_a].join[rand(36)]}.join %>
      provisioner:
        salt_bootstrap_options: -X -p rsync git v<%= version %>
    - name: ubuntu-17.10
      driver:
        tags:
          Name: kitchen-ubuntu-1710-<%= 10.times.map{[('a'..'z').to_a, (0..9).to_a].join[rand(36)]}.join %>
    - name: ubuntu-16.04
      driver:
        tags:
          Name: kitchen-ubuntu-1604-<%= 10.times.map{[('a'..'z').to_a, (0..9).to_a].join[rand(36)]}.join %>
    - name: ubuntu-14.04
      driver:
        tags:
          Name: kitchen-ubuntu-1404-<%= 10.times.map{[('a'..'z').to_a, (0..9).to_a].join[rand(36)]}.join %>
    - name: debian-8
      driver:
        tags:
          Name: kitchen-debian-8-<%= 10.times.map{[('a'..'z').to_a, (0..9).to_a].join[rand(36)]}.join %>
        block_device_mappings: null
    - name: debian-9
      driver:
        tags:
          Name: kitchen-debian-9-<%= 10.times.map{[('a'..'z').to_a, (0..9).to_a].join[rand(36)]}.join %>
        block_device_mappings: null
    - name: arch
      driver:
        image_search:
          owner-id: '093273469852'
          name: arch-linux-hvm-*.x86_64-ebs
        tags:
          Name: kitchen-arch-<%= 10.times.map{[('a'..'z').to_a, (0..9).to_a].join[rand(36)]}.join %>
      transport:
        username: root
      provisioner:
        salt_bootstrap_options: -X -p rsync git v<%= version %> >/dev/null
    - name: windows-2016
      driver:
        spot_price: '0.40'
        instance_type: t2.xlarge
        tags:
          Name: kitchen-windows-2016-<%= 10.times.map{[('a'..'z').to_a, (0..9).to_a].join[rand(36)]}.join %>
        retryable_tries: 120
      provisioner:
        salt_bootstrap_url: https://raw.githubusercontent.com/saltstack/salt-bootstrap/develop/bootstrap-salt.ps1
        salt_bootstrap_options: -version <%= version %> -runservice false
        init_environment: |
          reg add "hklm\system\currentcontrolset\control\session manager\memory management" /v pagingfiles /t reg_multi_sz /d "d:\pagefile.sys 4096 8192" /f
          winrm set winrm/config/winrs '@{MaxMemoryPerShellMB="5000"}'
      transport:
        name: winrm
      verifier:
        windows: true
        types:
          - unit
        coverage_xml: false
        save:
          $env:TEMP/salt-runtests.log: artifacts/logs/salt-runtests.log
          /salt/var/log/salt/minion: artifacts/logs/minion

The above is the platform file as it exists on our Jenkins nodes, it just needs to be added to the correct place. This has all the logic in place so that the newest ami is found on Amazon when the commands are run.

## Extra verifier config files ##

These file paths need to be exported as the `SALT_KITCHEN_VERIFIER` environment variable, or placed in `.kitchen/verifier.yml` in the git repository root.

### .kitchen/transport.yml ###

Used to run the transport tests. (For Centos 7 and Ubuntu 16.04)

    verifier:
      name: runtests
      sudo: true
      verbose: true
      run_destructive: true
      transport: tcp
      types:
        - ssh
      xml: /tmp/xml-unittests-output/
      coverage_xml: /tmp/coverage.xml
      save:
        /tmp/xml-unittests-output: artifacts/
        /tmp/coverage.xml: artifacts/coverage/coverage.xml
        /var/log/salt/minion: artifacts/logs/minion
        /tmp/salt-runtests.log: artifacts/logs/salt-runtests.log

### .kitchen/proxy.yml ###

Used to run the proxy tests. (For Centos 7 and Ubuntu 16.04)

    verifier:
      name: runtests
      sudo: true
      verbose: true
      run_destructive: true
      types:
        - proxy
      xml: /tmp/xml-unittests-output/
      coverage_xml: /tmp/coverage.xml
      save:
        /tmp/xml-unittests-output: artifacts/
        /tmp/coverage.xml: artifacts/coverage/coverage.xml
        /var/log/salt/minion: artifacts/logs/minion
        /tmp/salt-runtests.log: artifacts/logs/salt-runtests.log

## Running Kitchen Commands ##

Now that everything is all setup, kitchen commands can be run.

### Installing dependencies ###

While in the `salt` git repository where all the .kitchen/ directory files have been setup.  The first thing that needs to happen is the dependencies need to be installed, but only the dependencies required to run the tests

    bundle install --with ec2 windows --without opennebula docker

This will install the following and their dependencies.

- test-kitchen: The base library
- kitchen-salt: The saltstack provisioner
- kitchen-ec2: The ec2 driver, for testing instances
- kitchen-sync: The rsync transport (This is important because it preserves symlinks and is the fastest transport)
- winrm: For running commands on Windows test instances
- winrm-fs: For copying files to and from Windows test instances

### Exporting Credentials in Environment Variables ###

KitchenEC2 uses the [aws-ruby-sdk](https://github.com/aws/aws-sdk-ruby/#configuration) so any method specified for that can be used. On Jenkins, SaltStack injects the environment variables as private variables so if they are somehow compromised, Jenkins removes the strings from the output logs.

    export AWS_ACCESS_KEY_ID="<id string>" AWS_SECRET_ACCESS_KEY="<key string>"

This can be stored in .bashrc or whatever other shell environments file is used.

### Last setup steps ###

Make sure `rsync` is installed on the local machine.  Then using an ssh-agent, add the amazon ssh key to the ssh-agent.

    eval "$(ssh-agent)"
    ssh-add ~/.ssh/aws.pem

The rsync command is required for being able to copy symlinks over to the testing instances.  It is also significantly faster than using `scp` or `sftp`, which could take up to 15 minutes to upload the entire testing environment to the testing instance.

### Running Commands ###

Now that everything is setup, test instances can be run.

Running `bundle exec kitchen list` will show all of the different test cases that are available to be run based on the different configuration template files that have been setup.

    [root@kitchen-slave02-dev salt-ubuntu-1604-py2]# bundle exec kitchen list
    Instance          Driver  Provisioner  Verifier  Transport  Last Action    Last Error
    py2-opensuse      Ec2     SaltSolo     Runtests  Rsync      <Not Created>  <None>
    py2-centos-7      Ec2     SaltSolo     Runtests  Rsync      <Not Created>  <None>
    py2-centos-6      Ec2     SaltSolo     Runtests  Rsync      <Not Created>  <None>
    py2-fedora-26     Ec2     SaltSolo     Runtests  Rsync      <Not Created>  <None>
    py2-fedora-27     Ec2     SaltSolo     Runtests  Rsync      <Not Created>  <None>
    py2-ubuntu-1710   Ec2     SaltSolo     Runtests  Rsync      <Not Created>  <None>
    py2-ubuntu-1604   Ec2     SaltSolo     Runtests  Rsync      <Not Created>  <None>
    py2-ubuntu-1404   Ec2     SaltSolo     Runtests  Rsync      <Not Created>  <None>
    py2-debian-8      Ec2     SaltSolo     Runtests  Rsync      <Not Created>  <None>
    py2-debian-9      Ec2     SaltSolo     Runtests  Rsync      <Not Created>  <None>
    py2-arch          Ec2     SaltSolo     Runtests  Rsync      <Not Created>  <None>
    py2-windows-2016  Ec2     SaltSolo     Runtests  Winrm      <Not Created>  <None>
    py3-opensuse      Ec2     SaltSolo     Runtests  Rsync      <Not Created>  <None>
    py3-centos-7      Ec2     SaltSolo     Runtests  Rsync      <Not Created>  <None>
    py3-fedora-26     Ec2     SaltSolo     Runtests  Rsync      <Not Created>  <None>
    py3-fedora-27     Ec2     SaltSolo     Runtests  Rsync      <Not Created>  <None>
    py3-ubuntu-1710   Ec2     SaltSolo     Runtests  Rsync      <Not Created>  <None>
    py3-ubuntu-1604   Ec2     SaltSolo     Runtests  Rsync      <Not Created>  <None>
    py3-debian-8      Ec2     SaltSolo     Runtests  Rsync      <Not Created>  <None>
    py3-debian-9      Ec2     SaltSolo     Runtests  Rsync      <Not Created>  <None>
    py3-arch          Ec2     SaltSolo     Runtests  Rsync      <Not Created>  <None>
    py3-windows-2016  Ec2     SaltSolo     Runtests  Winrm      <Not Created>  <None>

Any of the Instances on the left can be used with kitchen.  Kitchen will build the server, and store information about it in `.kitchen/<instancename>.yml`.  This information is used for keeping track of which servers have been built and their instance ids. Part of the platform file above is tagging the instances with a `Name` tag so that they can be identified in the aws console, but an extra tag `{created-by: kitchen}` is also set so that they can easily be deleted.

To build an instance use the `create` command.

    bundle exec kitchen create py2-centos-7

All this does is build the instance.  Then the `converge` command can be used to run the `git.salt` state from [salt-jenkins](https://github.com/saltstack/salt-jenkins).

    bundle exec kitchen converge py2-centos-7

At any point if some command just needs to be run on the server, `login` can be used for Linux machines.

    bundle exec kitchen login py2-centos-7

For windows, this opens a RDP session for the windows machine, and that port will need to be added to the security group that is being used. (With powershell now available on Mac and Linux, it would be great to be able to just login to the Windows machines)

Once the machine has been converged, the verifier can be used to run the test suite.

    bundle exec kitchen verify py2-centos-7

And when the machine is no longer useful, it can be deleted.

    bundle exec kitchen destroy py2-centos-7

And that is the life cycle of the testing instances in https://jenkinsci.saltstack.com

Jenkins however uses `test`, which will create, then converge, then verify, and if verify passes, the instance will be deleted, otherwise Jenkins delete it in a clean up command.

The custom runtests verifier is used explicitly for the salt test suite, and will download all junit files for jenkins.
