ntp:
  pkg.installed:
    - name: ntp
  service.running:
    - name: ntp
