def test_ping(salt):
    assert salt('test.ping') is True
