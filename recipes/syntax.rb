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
  # If we changed a cookbook but didn't bump the version than the build
  # phase will fail when trying to upload to the Chef Server.
  unless bumped_version?(cookbook.path)
    raise RuntimeError,
%{The #{cookbook.name} cookbook was modified but the version was not updated in the metadata file.

The version must be updated when any of the following files are modified:
   metadata.(rb|json)
   Berksfile
   Berksfile.lock
   Policyfile.rb
   Policyfile.lock.json
   recipes/.*
   attributes/.*
   libraries/.*
   files/.*
   templates/.*}
  end

  # Run `knife cookbook test` against the modified cookbook
  execute "syntax_check_#{cookbook.name}" do
    command "knife cookbook test -o #{cookbook.path} -a"
  end
end
