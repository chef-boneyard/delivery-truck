functional:
	KITCHEN_YAML=.kitchen.docker.yml bundle exec kitchen verify

functional-destroy:
	KITCHEN_YAML=.kitchen.docker.yml bundle exec kitchen destroy
