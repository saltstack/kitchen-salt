from __future__ import unicode_literals, print_function
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


@pytest.mark.xfail
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


def test_cache_command_ran(salt):
    files = salt('cp.list_master')
    print(files)
    assert 'cache_commands_test' in files


@pytest.mark.skipif('windows' not in os.environ.get('KITCHEN_INSTANCE'), reason='Skip windows specific test')
def test_path_line_endings(salt):
    res = salt('cp.get_file_str', 'salt://top.sls')
    assert res == '---\r\nbase:\r\n  "*":\r\n  - foo\r\n'
