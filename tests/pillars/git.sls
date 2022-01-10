git:
  client:
    enabled: true
    pkgs:
    - git
    user:
    - user:
        name: jdoe
        email: j@doe.com
linux:
  system:
    enabled: true
    user:
      jdoe:
        enabled: true
        sudo: true
        full_name: John Doe
        gid: users
        home: /home/jdoe
