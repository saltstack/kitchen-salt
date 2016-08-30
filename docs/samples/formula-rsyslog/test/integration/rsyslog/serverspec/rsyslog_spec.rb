require 'serverspec'

# Required by serverspec
set :backend, :exec

describe package('rsyslog') do
  it { is_expected.to be_installed }
end

describe service('rsyslog') do
  it { is_expected.to be_enabled }
  it { is_expected.to be_running }
end
