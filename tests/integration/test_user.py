import os
import pytest


@pytest.mark.skipif('freebsd' in os.environ.get('KITCHEN_INSTANCE'), reason='Skip on freebsd images')
@pytest.mark.skipif('windows' in os.environ.get('KITCHEN_INSTANCE'), reason='Skip on windows images')
def test_jdoe(host):
    jdoe = host.user('jdoe')
    assert jdoe.name == 'jdoe'
    assert jdoe.home == '/home/jdoe'
