<!--
# @markup markdown
# @title Runtests Verifier
# @author SaltStack Inc.
-->

# The Runtests Verifier #

The runtests verifier is used to run the SaltStack test suite's `tests/runtests.py` command.

## Runtests Options ##

### testingdir ###

default: `/testing`

This is the path inside of the kitchen root dir (default: /tmp/kitchen/) where the tests should be run.

The .kitchen.yml in the salt repository puts the git repo at /tmp/kitchen/testing, so the default for this option is /testing.

### python_bin ###

default: `python2`

Python command to use to execute the test suite.  Can be a relative or absolute path.

### verbose ###

default: `false`

Set to True to pass an extra `-v` to the test suite for more verbose output.

### run_destructive ###

default: `false`

Set to True to pass `--run-destructive` to the test suite.

### xml ###

default: `false`

Set to the path of a directory where the xml junit files should be dumped.

### coverage_xml ###

default: `false`

Set to the path where the coverage.xml file should be placed.

### types ###

default: `[]`

List of the different types of tests to run.  Examples are `unit`, `integration`, `api`, etc.

A `--` will be placed at the front of the option before passing it to runtests.py.

### tests ###

default: `[]`

List of single tests to run with `--name` or `-n`.

This can also be set with a space seperated list of tests to run in the `KITCHEN_TESTS` environment variable.

    verifier:
      tests:
        - integration.states.test_pip.PipStateTest.test_46127_pip_env_vars

or

    KITCHEN_TESTS='integration.states.test_pip.PipStateTest.test_46127_pip_env_vars' bundle exec kitchen verify py2-centos-7

### transport ###

default: `false`

Set to `zeromq` or `tcp` to test different transport layers specifically. If not set, runtests.py defaults to using `zeromq`

### save ###

default: `{}`

A dictionary of files to save download to the filesystem to download once the test suite has completed.  The salt verifier has the following.

    save:
        /tmp/xml-unittests-output: artifacts/
        /tmp/coverage.xml: artifacts/coverage/coverage.xml
        /tmp/kitchen/var/log/salt/minion: artifacts/logs/minion
        /tmp/salt-runtests.log: artifacts/logs/salt-runtests.log

### sudo ###

default: `false`

Set to `true` to execute the runtests.py command with sudo.  This is required if the username in the transport is not `root`

### windows ###

default: `false`

Set to `true` to make changes for running the windows test suite.  This only runs a subset of the test suite, whitelisted by `tests/whitelist.txt` in the salt repository
