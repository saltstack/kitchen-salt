<!--
# @markup markdown
# @title .kitchen.yml
# @author SaltStack Inc.
-->

# Example Configuration #

    driver:
      name: docker
      use_sudo: false
      privileged: true
      forward:
        - 80

    transport:
      name: sftp

    provisioner:
      name: salt_solo
      salt_install: bootstrap
      is_file_root: true
      require_chef: false
      salt_copy_filter:
        - .git
      dependencies:
        - name: apache
          repo: git
          source: https://github.com/saltstack-formulas/apache-formula.git
        - name: mysql
          repo: git
          source: https://github.com/saltstack-formulas/mysql-formula.git
        - name: php
          repo: git
          source: https://github.com/saltstack-formulas/php-formula.git
      state_top:
        base:
          "*":
            - wordpress
      pillars:
        top.sls:
          base:
            "*":
              - wordpress
      pillars_from_files:
        wordpress.sls: pillar.example

    platforms:
      - name: centos
        driver_config:
          run_command: /usr/lib/systemd/systemd

    suites:
      - name: nitrogen
        provisioner:
          salt_bootstrap_options: -X -p git stable 2017.7
      - name: carbon
        provisioner:
          salt_bootstrap_options: -X -p git stable 2016.11

    verifier:
      name: shell
      remote_exec: false
      command: pytest -v tests/integration/
