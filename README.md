<!--
# @markup markdown
# @title README
# @author SaltStack Inc.
-->
# kitchen-salt
[![Gem Version](https://badge.fury.io/rb/kitchen-salt.svg)](http://badge.fury.io/rb/kitchen-salt)
[![Gem Downloads](http://ruby-gem-downloads-badge.herokuapp.com/kitchen-salt?type=total&color=brightgreen)](https://rubygems.org/gems/kitchen-salt)
[![Build Status](https://travis-ci.org/saltstack/kitchen-salt.png)](https://travis-ci.org/saltstack/kitchen-salt)
[![Build Status](https://drone.gtmanfred.com/api/badges/saltstack/kitchen-salt/status.svg)](https://drone.gtmanfred.com/saltstack/kitchen-salt)

A Test Kitchen Provisioner for Salt

The provider works by generating a salt-minion config, creating pillars based on attributes in .kitchen.yml & calling salt-call.

This provider has been tested against the Ubuntu boxes running in vagrant/virtualbox & vagrant-lxc boxes on Ubuntu.

## Installation & Setup
You'll need the test-kitchen & kitchen-salt gem's installed in your system, along with kitchen-vagrant or some other suitable driver for test-kitchen.  Please see the {file:docs/INTRODUCTION.md}.

## Provisioner Options
More details on all the configuration optins are in {file:docs/provisioner_options.md}

## Requirements
You'll need a driver box that is supported by the SaltStack [bootstrap](https://github.com/saltstack/salt-bootstrap) system.

## Continuous Integration & Testing
PR's and other changes should validated using Travis-CI, kitchen-docker, multiple state dependencies, the modified version of kitchen-salt and the latest version of test-kitchen.

## Releasing

    # hack. work. test.
    git add stuff
    git commit -v
    gem bump --release --tag
