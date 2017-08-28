import pytest
import os

@pytest.mark.skipif('windows' in os.environ.get('KITCHEN_INSTANCE'), reason='Skip on freebsd images')
@pytest.mark.parametrize("pkgname", [
    "git",
])
def test_pkg(host, pkgname):
    pkg = host.package(pkgname)
    assert pkg.is_installed is True
