import os
import testinfra
import unittest


class Test(unittest.TestCase):

    def setUp(self):
        self.host = testinfra.get_host("docker://kitchen@{0}".format(os.environ.get('KITCHEN_CONTAINER_ID')))

    def test_jdoe(self):
        jdoe = self.host.user('jdoe')
        self.assertEqual(jdoe.name, 'jdoe')
        self.assertEqual(jdoe.home, '/home/jdoe')


if __name__ == "__main__":
    unittest.main()
