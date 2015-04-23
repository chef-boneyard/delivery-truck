require 'serverspec'

set :backend, :exec

describe 'Check Chef Gems' do
  # dbuild can run docker as sudo
  describe command('sudo -E docker') do
    its(:exit_status) { should eq 0 }
  end
end
