# kitchen-salt #
[![Gem Version](https://badge.fury.io/rb/kitchen-salt.svg)](http://badge.fury.io/rb/kitchen-salt)
[![Gem Downloads](http://ruby-gem-downloads-badge.herokuapp.com/kitchen-salt?type=total&color=brightgreen)](https://rubygems.org/gems/kitchen-salt)
[![Build Status](https://travis-ci.org/saltstack/kitchen-salt.png)](https://travis-ci.org/saltstack/kitchen-salt)

A Test Kitchen Provisioner for Salt

The provider works by generating a salt-minion config, creating pillars based on attributes in .kitchen.yml and calling salt-call.

This provisioner is tested with kitchen-docker against CentOS, Ubuntu, and Debian.
