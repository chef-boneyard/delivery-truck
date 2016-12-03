#
# Copyright:: Copyright (c) 2015 Chef Software, Inc.
# License:: Apache License, Version 2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

changed_cookbooks.each do |cookbook|
  # Run Foodcritic against any cookbooks that were modified.
  execute "lint_foodcritic_#{cookbook.name}" do
    command "foodcritic #{foodcritic_fail_tags} #{foodcritic_tags} " \
      "#{foodcritic_excludes} #{cookbook.path}"
  end

  # Run cookstyle against any cookbooks that were modified
    if %[which cookstyle] != nil
      execute "lint_cookstyle_#{cookbook.name}" do
        command "cookstyle #{cookbook.path}"
        environment(
          # workaround for https://github.com/bbatsov/rubocop/issues/2407
          'USER' => (ENV['USER'] || 'dbuild')
        )
        live_stream true
      end
    else
        # Run Rubocop against any cookbooks that were modified.
        execute "lint_rubocop_#{cookbook.name}" do
          command "rubocop #{cookbook.path}"
          environment(
            # workaround for https://github.com/bbatsov/rubocop/issues/2407
            'USER' => (ENV['USER'] || 'dbuild')
          )
          only_if { File.exist?(File.join(cookbook.path, '.rubocop.yml')) }
        end
    end
  # end
end
