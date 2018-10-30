import os
import pytest


@pytest.mark.skipif('freebsd' in os.environ.get('KITCHEN_INSTANCE'), reason='Skip on freebsd images')
@pytest.mark.skipif('windows' in os.environ.get('KITCHEN_INSTANCE'), reason='Skip on windows')
def test_gpg_pillar(salt):
    assert salt('pillar.get', 'gpg:test') == 'supersecret'
