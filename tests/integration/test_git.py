import pytest

@pytest.mark.parametrize("pkgname", [
    "git",
])
def test_pkg(host, pkgname):
    pkg = host.package(pkgname)
    assert pkg.is_installed is True
