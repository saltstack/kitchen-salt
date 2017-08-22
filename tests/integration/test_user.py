def test_jdoe(host):
    jdoe = host.user('jdoe')
    assert jdoe.name == 'jdoe'
    assert jdoe.home == '/home/jdoe'
