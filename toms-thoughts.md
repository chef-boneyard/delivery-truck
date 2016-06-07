change_id = node['delivery']['change']['change_id']
tag = Dir.chdir(node['delivery']['workspace']['repo']){
  `git tag -l | sort -V|tail -n1`.strip
}

application_hash = {
  'delivery': tag
}

cookbook_hash = {}
node['delivery']['project_cookbooks'].each do |cb|
  cb_dir = ::File.join(node['delivery']['workspace']['repo'], "/cookbooks/", cb)
  metadata = Chef::Cookbook::Metadata.new
  metadata.from_file(::File.expand_path(::File.join(cb_dir, "metadata.rb")))
  cookbook_hash[cb] = metadata.version
end



We need some way to initially seed the promotion data. Adding a new helper to delivery-(sugar|truck)
might be useful here. The idea is that this would be used in the publish phase.

  delivery_changeset change_id do
    applications application_hash
    cookbooks cookbook_hash
    action :save
  end

  

This is what would create the data bag item.

In acceptance/provision, we would pull that data bag item (if it exists) and use it.

In union/provision, we would pull the changeset bag corresponding with the change_id
of the union run, and update the union environment with those pinnings instead of
the pinnings from acceptance.

From rehearsal/provision onwards, delivery-truck would operate as normal.


We could also very easily provide a `:delete` action for the resource, allowing
people to cleanup the data bags if they so wish.
