import testinfra


def test_jdoe(User):
    jdoe = User('jdoe')
    assert jdoe.name == 'jdoe'
    assert jdoe.home == '/home/jdoe'
