# `delivery-truck`
`delivery-truck` is a Chef Delivery build cookbook for continuously delivering
Chef cookbooks. To quickly get started you just need to set `delivery-truck` to
be your build cookbook in your `.delivery/config.json`.

## Customizing Behavior using `.delivery/config.json`
The behavior of the `delivery-truck` cookbook phase recipes can be easily
controlled by specifying certain values in your `.delivery/config.json` file.
The control these values offer you is limited and not meant as a method to
drastically alter the way the recipe functions.

### deploy

### functional
The `functional` phase will execute [test-kitchen](http://kitchen.ci) using the
[kitchen-docker](http://github.com/portertech/kitchen-docker) driver. In order for
tests to be executed you *must* have a `.kitchen.docker.yml` file in the root each
cookbook in your project that you want to test. An example file can be see in the
root of this project.

### lint
The `lint` phase will execute [foodcritic](http://foodcritic.io) but you can specify
which rules you would like to follow directly from your `config.json`.

* `ignore_rules` - Provide a list of foodcritic rules you would like to ignore.
* `only_rules` - Explictly state which foodcritic rules you would like to run.
Any other rules except these will be ignored.

```json
{
  "build_attributes": {
    "lint": {
      "foodcritic": {
        "ignore_rules": ["FC001"],
        "only_rules": ["FC002"]
      }
    }
  }
}
```

### provision

### quality

### publish
From the `publish` phase you can quickly and easily deploy cookbooks to
your Chef Server and your entire project to a Github account.

* `chef_server` - Set to true/false depending on whether you would like to
upload any modified cookbooks to the Chef Server associated with Delivery.
* `github` - Specify the Github repository you would like to push your project
to. In order to work you must create a shared secrets data bag item (see "Shared
Secrets" below) with a key named `github` with the value
being a [deploy key](https://developer.github.com/guides/managing-deploy-keys/)
with access to that repo.

*Example .delivery/config.json*
```json
{
  "build_attributes": {
    "publish": {
      "chef_server": true,
      "github": "<org>/<project>"
    }
  }
}
```

*Example Github shared secrets databag*
```json
{
  "id": "<your ID here>",
  "github": "<private key>"
}
```

### security

### smoke

### syntax

### unit

## Handling Secrets
This cookbook implements a rudamentary approach to handling secrets. This process
is largely out of band from Chef Delivery for the time being.

`delivery-truck` will look for secrets in the `delivery-secrets` data bag on the
Delivery Chef Server. It will expect to find an item in that data bag named
`<ent>-<org>-<project>`. For example, this cookbook is kept in the
'Delivery-Build-Cookbooks' org of the 'chef' enterprise so it's data bag name is
`chef-Delivery-Build-Cookbooks-delivery-truck`.

This cookbook expects this data bag item to be encrypted with the same
encrypted_data_bag_secret that is on your builders. You will need to ensure that
the data bag is available on the Chef Server before you run this cookbook for
the first time otherwise it will fail.

## Custom Resources
`delivery-truck` includes a number of custom resources that you can use in your
phase recipes to easily describe the different actions you would like to take
in a human readable, idempotent fashion.

#### test_kitchen
The `test_kitchen` resource allows you to interact with the Test Kitchen API to run
integration tests during your functional phase.

It will accept the following parameters:
* project_path (name) - the path to the directory that contains the project (cookbook) you wish to test
* config - the path to kitchen.yml. defaults to `File.join(project_path, '.kitchen.yml')`
* platforms - regex of platforms you'd like to test. Defaults to `*`
* suites - regex of suites you'd like to test. Defaults to `*`

#### supermarket
The `supermarket` resource will allow you to interact with the Supermarket API,
allowing you to continuously deliver your cookbooks to the Supermarket of your
choice.

It will accept the following parameters:
* url (name) - the url to the Supermarket API endpoint.
* cookbooks - the list of cookbooks to push to supermarket
* username - the username to release the cookbook under
* private_key - the path (or contents) of the private key associated with the user

#### chef_server
The `chef_server` resource allows you to interact with the Chef Server API,
allowing you to easily upload Chef objects to the Chef Server of your choice.

It will accept the following parameters:
* url (name) - the URL to the Chef Server
* config - the path to the knife.rb config. Defaults to the `delivery` user's knife.rb
* cookbooks - array of paths to cookbooks you would like to the upload
* policyfiles - array of paths to policyfiles you would like to upload
* roles - array of paths to roles you would like to upload
* environments - array of paths to environment files you would like to upload
* data_bags - array of paths to data bags you would like to upload.

#### foodcritic
The `foodcritic` resource will allow you to run `foodcritic` against cookbooks
in your Delivery project.

It will accept the following parameters:
* path (name) - the path to the cookbook you would like to run foodcritic against
* ignore_rules - array of foodcritic rules you would like to ignore
* only_rules - array of foodcritic rules you would like to exclusively run

#### jsonlint
The `jsonlint` resource will allow you to lint the .json files you have in your
Delivery project.

It will accept the following parameters:
* path (name) - the path to the JSON file

#### rubylint
The `rubylint` resource will allow you to lint the .rb files you have in your
Delivery project.

It will accept the following parameters:
* path (name) - the path to the Ruby file

#### knife_cookbook_test
The `knife_cookbook_test` resource will allow you to run `knife cookbook test`
against the cookbooks in your Delivery project.

It will accept the following parameters:
* path (name) - the path to the cookbook you would like to test

## Local Development
* You will need boot2docker (or some other Docker VM)

### make commands
`make functional`
