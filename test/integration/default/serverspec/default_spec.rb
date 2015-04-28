require 'serverspec'

set :backend, :exec

describe 'Check Chef Gems' do
  describe command('/opt/chef/embedded/bin/gem list --local | grep -iw -- ^kitchen-docker | grep -w -- "[(\ \]1.7.0[,)]"') do
    its(:exit_status) { should eql 0 }
  end

  describe command('/opt/chef/embedded/bin/gem list --local | grep -iw -- ^chefspec | grep -w -- "[(\ \]4.1.1[,)]"') do
    its(:exit_status) { should eql 0 }
  end

  describe command('/opt/chef/embedded/bin/gem list --local | grep -iw -- ^chef-sugar | grep -w -- "[(\ \]2.5.0[,)]"') do
    its(:exit_status) { should eql 0 }
  end
end
