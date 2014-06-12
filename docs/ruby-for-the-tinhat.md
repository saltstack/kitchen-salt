RVM give you the willies?


Try this, start with Debian Testing/Jessie and add the bits of ruby we need:

    # PREREQ: install Vagrant from http://www.vagrantup.com/
    # install enough for a sensible ruby execution environment
    sudo apt-get install ruby bundler git

Now lets get a sample salt repo that's been prepared for test-kitchen:

    git clone https://github.com/simonmcc/beaver-formula.git
    cd beaver-formula/



