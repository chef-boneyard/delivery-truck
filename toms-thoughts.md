change_id = node['delivery']['change']['change_id']
tag = Dir.chdir(node['delivery']['workspace']['repo']){
  `git tag -l | sort -V|tail -n1`.strip
}

attributes_hash = {
  'applications': {
    'delivery': tag
  }
}

cookbook_hash = {}
node['delivery']['project_cookbooks'].each do |cb|
  cb_dir = ::File.join(node['delivery']['workspace']['repo'], "/cookbooks/", cb)
  metadata = Chef::Cookbook::Metadata.new
  metadata.from_file(::File.expand_path(::File.join(cb_dir, "metadata.rb")))
  cookbook_hash[cb] = metadata.version
end

delivery_change.project

We need some way to initially seed the promotion data. Adding a new helper to delivery-(sugar|truck)
might be useful here. The idea is that this would be used in the publish phase.

  # in publish.rb

  delivery_changeset change_id do
    attributes attributes_hash
    cookbooks cookbook_hash
    action :save
  end

build/publish - create dbi with only details from attributes & cookbooks

blocked - PIPELINE_ID is blocked on CHANGE_ID

attributes & cookbook pinnings (JSON Hash) - associated with a change id

id | shipment_id | pipeline_id | change_id | safe (bool) | attributes | cookbooks

build/publish
  * create the DBI

acceptance/provision
  * pull in DBI, update acceptance environment, proceed

union/provision
  * pull in DBI, update union environment, proceed

rehearsal/provision
  * remove the DBI


build finish (success) - update acceptance chef env with data for specific change_id
change delivered - update union chef env with data for specific change_id
union finish (success) - update rehearsal chef env with data for all impacted changes (change, and everything that was removed from blocked list)
rehearsal finish (success) - update delivered chef env with data for all impacted changes

acceptance/provision - pull in dbi, merge with env
union/provision - pull in dbi, merge with env
union/(functional|smoke) - if fail, mark dbi as unsafe
union/functional - if pass, mark dbi as safe
rehearsal/provision - pull in and merge all safe dbi's
delivered/provision - pull in everything from rehearsal
delivered/functional - does nothing

accept - pulls in specific change
union - pulls in specific change
rehearsal - pulls in all "safe" changes from union
delivered - pulls everything from rehearsal

U    R    D
A
B
C

In progress <-- deploy
Known good

figure out the pinnings we're testing
Determine those pinnings to be be good/bad

data_bag = {
  id: change_id,
  status: null | safe | unsafe,
  cookbooks: {},
  attributes: {}
}

This is what would create the data bag item.

In acceptance/provision, we would pull that data bag item (if it exists). We would
update the cookbook pinnings based on the cookbooks hash.

In union/provision, we would pull the changeset bag corresponding with the change_id
of the union run, and update the union environment with those pinnings instead of
the pinnings from acceptance.

From rehearsal/provision onwards, delivery-truck would operate as normal.

We could also very easily provide a `:delete` action for the resource, allowing
people to cleanup the data bags if they so wish.


If we treat the `node['delivery']` Mash as automatic attributes, we could have a
simple sugar handler like this:

  delivery_change change_id do
    action :promote
  end

to replace the Ruby block we have now.
