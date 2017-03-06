name             'delivery-truck'
maintainer       'Chef Delivery Team'
maintainer_email 'delivery-team@chef.io'
license          'Apache 2.0'
description      'Delivery build_cookbook for your cookbooks!'

version          '2.3.2'

source_url       'https://github.com/chef-cookbooks/delivery-truck'
issues_url       'https://github.com/chef-cookbooks/delivery-truck/issues'

supports 'ubuntu', '>= 12.04'
supports 'redhat', '>= 6.5'
supports 'centos', '>= 6.5'

depends 'delivery-sugar', '~> 1.1'
