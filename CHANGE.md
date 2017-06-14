v0.0.19
* Added ability to copy additional dependency formulas into the VM
  See https://github.com/saltstack/kitchen-salt/blob/master/provisioner_options.md#dependencies

v0.0.18
* Added ability to filter paths from the set of files copied to the guest
  See https://github.com/saltstack/kitchen-salt/blob/master/provisioner_options.md#salt_copy_filter
* Added is_file_root flag - treat this project as a complete file_root.
  See https://github.com/saltstack/kitchen-salt/blob/master/provisioner_options.md#is_file_root
* Pillar data specified using the pillars-from-files option are no longer
  passed through YAML.load/.to_yaml
  This was causing subtle data transformations with unexpected results when
  the reuslting yaml was consumed by salt
* Added "Data failed to compile" and "No matching sls found for" to
  strings we watch salt-call output for signs of failure

