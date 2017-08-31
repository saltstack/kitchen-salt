import os
import pytest


def test_ping(salt):
    #print(os.environ)
    assert salt('test.ping') is True


@pytest.mark.skipif('freebsd' in os.environ.get('KITCHEN_INSTANCE'), reason='Skip on freebsd images')
@pytest.mark.skipif('windows' in os.environ.get('KITCHEN_INSTANCE'), reason='git not installed on windows')
def test_git_depends(salt):
    formulas = {'linux', 'git'}
    dirs = salt('cp.list_master_dirs')
    assert all([formula in dirs for formula in formulas])


@pytest.mark.skipif('centos' in os.environ.get('KITCHEN_INSTANCE'), reason='Skip on centos images')
@pytest.mark.skipif('freebsd' in os.environ.get('KITCHEN_INSTANCE'), reason='Skip on freebsd images')
@pytest.mark.skipif('windows' in os.environ.get('KITCHEN_INSTANCE'), reason='APT not supported on windows')
def test_apt_depends(salt):
    formulas = {'nginx',}
    dirs = salt('cp.list_master_dirs')
    assert all([formula in dirs for formula in formulas])


@pytest.mark.skipif('windows' in os.environ.get('KITCHEN_INSTANCE'), reason='git not installed on windows')
def test_postfix_depends(salt):
    formulas = {'postfix',}
    dirs = salt('cp.list_master_dirs')
    assert all([formula in dirs for formula in formulas])


@pytest.mark.skipif('windows' in os.environ.get('KITCHEN_INSTANCE'), reason='spm not supported on windows')
def test_spm_depends(salt):
    formulas = {'hubblestack_nova'}
    dirs = salt('cp.list_master_dirs')
    print(dirs)
    assert all([formula in dirs for formula in formulas])


def test_path_depends(salt):
    formulas = set(['foo',])
    dirs = salt('cp.list_master_dirs')
    print(dirs)
    assert all([formula in dirs for formula in formulas])
