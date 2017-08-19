import os
import testinfra
import unittest


class Test(unittest.TestCase):

    def setUp(self):
        self.host = testinfra.get_host("docker://kitchen@{0}".format(os.environ.get('KITCHEN_CONTAINER_ID')))

    def test_pkg(self):
        pkg= self.host.package('git')
        self.assertTrue(pkg.is_installed)


if __name__ == "__main__":
    unittest.main()
