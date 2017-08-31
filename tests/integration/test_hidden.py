import os
import pytest


@pytest.mark.skipif('windows' in os.environ.get('KITCHEN_INSTANCE'), reason='dotfiles are ignored on windows')
def test_hidden_dirs(salt):
    expected = ('tests/.hidden',)
    ignored = ('tests/.filter_hidden',)
    dirs = salt('cp.list_master_dirs')
    assert all([exp in dirs for exp in expected])
    assert not any([exp in dirs for exp in ignored])


@pytest.mark.skipif('windows' in os.environ.get('KITCHEN_INSTANCE'), reason='dotfiles are ignored on windows')
def test_hidden_sls(salt):
    expected = ('tests/.hidden/test.sls',)
    ignored = ('tests/.filter_hidden/test.sls',)
    dirs = salt('cp.list_master')
    assert all([exp in dirs for exp in expected])
    assert not any([exp in dirs for exp in ignored])
