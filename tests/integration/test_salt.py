def test_ping(salt):
    assert salt('test.ping') is True

def test_git_depends(salt):
    formulas = {'linux', 'git', 'postfix'}
    dirs = salt('cp.list_master_dirs')
    assert all([formula in dirs for formula in formulas])

def test_apt_depends(salt):
    formulas = {'nginx',}
    dirs = salt('cp.list_master_dirs')
    assert all([formula in dirs for formula in formulas])

def test_spm_depends(salt):
    formulas = {'hubblestack_nova'}
    dirs = salt('cp.list_master_dirs')
    print(dirs)
    assert all([formula in dirs for formula in formulas])

def test_path_depends(salt):
    formulas = {'foo',}
    dirs = salt('cp.list_master_dirs')
    assert all([formula in dirs for formula in formulas])
