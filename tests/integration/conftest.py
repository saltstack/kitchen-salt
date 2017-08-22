import functools
import os
import pytest
import testinfra

test_host = testinfra.get_host('docker://kitchen@{0}'.format(os.environ.get('KITCHEN_CONTAINER_ID')))

@pytest.fixture
def host():
    return test_host

@pytest.fixture
def salt():
    return functools.partial(test_host.salt, local=True, config='/tmp/kitchen/etc/salt')
