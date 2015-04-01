# `delivery-truck`
`delivery-truck` is a Chef Delivery build_cookbook for continuously delivering
Chef cookbooks.

_This is alpha stage software, and is in a state of perpetual change. Use at your own risk!_

To quickly get started you just need to set `delivery-truck` to
be your build cookbook in your `.delivery/config.json`.

```
{
  "version": "2",
  "build_cookbook": {
    "name": "delivery-truck",
    "git": "https://github.com/opscode-cookbooks/delivery-truck.git"
  }
}
```

## Customizing Behavior using `.delivery/config.json`
The behavior of the `delivery-truck` cookbook phase recipes can be easily
controlled by specifying certain values in your `.delivery/config.json` file.
The control these values offer you is limited and not meant as a method to
drastically alter the way the recipe functions.

### lint
The `lint` phase will execute [foodcritic](http://foodcritic.io) but you can specify
which rules you would like to follow directly from your `config.json`.

* `ignore_rules` - Provide a list of foodcritic rules you would like to ignore.
* `only_rules` - Explictly state which foodcritic rules you would like to run.
Any other rules except these will be ignored.

```json
{
  "version": "2",
  "build_cookbook": {..},
  "delivery-truck": {
    "lint": {
      "foodcritic": {
        "ignore_rules": ["FC001"],
        "only_rules": ["FC002"]
      }
    }
  }
}
```

### publish
From the `publish` phase you can quickly and easily deploy cookbooks to
your Chef Server and your entire project to a Github account.

* `chef_server` - Set to true/false depending on whether you would like to
upload any modified cookbooks to the Chef Server associated with Delivery.
* `github` - Specify the Github repository you would like to push your project
to. In order to work you must create a shared secrets data bag item (see "Handling
Secrets" below) with a key named github with the value being a
[deploy key](https://developer.github.com/guides/managing-deploy-keys/) with
access to that repo.

```json
{
  "version": "2",
  "build_cookbook": {..},
  "delivery-truck": {
    "publish": {
      "chef_server": true,
      "github": "<org>/<project>"
    }
  }
}
```

*example data bag*
```json
{
  "id": "<your ID here>",
  "github": "<private key>"
}
```

## Skipped Phases
The following phases have no content and can be skipped: functional,
quality, security and smoke.

```json
{
  "version": "2",
  "build_cookbook": {..},
  "skip_phases": [
    "funcitonal",
    "quality",
    "security",
    "smoke"
  ]
}
```

## Handling Secrets (ALPHA)
This cookbook implements a rudimentary approach to handling secrets. This process
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

To get this data bag you can use the DSL `get_project_secrets` to get the
contents of the data bag.

```
my_secrets = get_project_secrets
puts my_secrets['id'] # chef-Delivery-Build-Cookbooks-delivery-truck
```

## License & Authors
- Author:: Tom Duffield (<tom@chef.io>)
- Author:: Salim Afiune (<afiunes@chef.io>)

```text
Copyright:: 2015 Chef Software, Inc

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
```
