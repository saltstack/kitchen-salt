rsyslog:
  pkg.installed:
    - name: rsyslog
  service.running:
    - name: rsyslog
    - enable: true
