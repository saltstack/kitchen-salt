describe package('ntp') do
  it { is_expected.to be_installed }
end

describe service('ntp') do
  it { is_expected.to be_enabled }
  it { is_expected.to be_running }
end
