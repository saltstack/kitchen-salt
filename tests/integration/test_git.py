import pytest
import os

@pytest.mark.parametrize("pkgname", [
    "git",
])
def test_pkg(host, pkgname):
    print(os.environ)
    pkg = host.package(pkgname)
    assert pkg.is_installed is True
