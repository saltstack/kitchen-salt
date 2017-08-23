import functools
import os
import pytest
import testinfra

if os.environ.get('KITCHEN_USERNAME') == 'vagrant':
    test_host = testinfra.get_host('paramiko://{KITCHEN_USERNAME}@{KITCHEN_HOSTNAME}:{KITCHEN_PORT}'.format(**os.environ),
                                   ssh_identity_file=os.environ.get('KITCHEN_SSH_KEY'))
else:
    test_host = testinfra.get_host('docker://{KITCHEN_USERNAME}@{KITCHEN_CONTAINER_ID}'.format(**os.environ))

@pytest.fixture
def host():
    return test_host

@pytest.fixture
def salt():
    test_host.run('sudo chown -R {0} /tmp/kitchen'.format(os.environ.get('KITCHEN_USERNAME')))
    return functools.partial(test_host.salt, local=True, config='/tmp/kitchen/etc/salt')
