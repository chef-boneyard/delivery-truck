require 'spec_helper'

describe DeliveryTruck::Helpers::Provision do
  let(:project_name) { 'delivery' }
  let(:change_id) { 'change-id' }

  let(:node) { instance_double('Chef::Node') }

  let(:node) do
    node = Chef::Node.new
    node.default_attrs = node_attributes
    node
  end

  let(:node_attributes) do
    {
      'delivery' => {
        'change' => {
          'project' => project_name,
          'change_id' => change_id
        }
      }
    }
  end

  describe '.project_cookbook_version_pins_from_env' do
    let(:cookbook_versions) do
      {
        project_name => '= 0.3.0',
        'cookbook-1' => '= 1.2.0',
        'cookbook-2' => '= 2.0.0'
      }
    end

    let(:env) do
      env = Chef::Environment.new
      env.name('test-env')
      env.cookbook_versions(cookbook_versions)
      env
    end

    context 'when the project is a cookbook' do
      it 'returns the cookbook version pinning' do
        expected_cookbook_pinnings = {
          project_name => '= 0.3.0'
        }
        cookbook_pinnings =
          described_class.project_cookbook_version_pins_from_env(node, env)
        expect(cookbook_pinnings).to eq(expected_cookbook_pinnings)
      end
    end

    describe 'when the repository contains multiple project cookbooks' do
      before(:each) do
        node_attributes['delivery']['project_cookbooks'] = ['cookbook-1',
                                                            'cookbook-2']
      end

      it 'returns the version pinnings of the project cookbooks' do
        expected_cookbook_pinnings = {
          'cookbook-1' => '= 1.2.0',
          'cookbook-2' => '= 2.0.0'
        }
        cookbook_pinnings =
          described_class.project_cookbook_version_pins_from_env(node, env)
        expect(cookbook_pinnings).to eq(expected_cookbook_pinnings)
      end
    end
  end

  describe '.project_application_version_pins_from_env' do
    let(:env) do
      env = Chef::Environment.new
      env.name('test-env')
      env.override_attributes = {
        'applications' => application_versions
      }
      env
    end

    context 'when the project is not an application' do
      let(:application_versions) { {} }

      it 'returns no application version pinnings' do
        expect(
          described_class.project_application_version_pins_from_env(node, env)
        ).to eq({})
      end

      context 'when the project is an application' do
        let(:application_versions) do
          {
            project_name => '0_3_562'
          }
        end

        it 'sets the project as the project application and returns project' \
           ' application version pinning' do
          expect(
            described_class.project_application_version_pins_from_env(node, env)
          ).to eq({project_name => '0_3_562'})
        end
      end
    end

    context 'when the project contains multiple applications' do
      let(:application_versions) do
        {
          'app-1' => '0_3_562',
          'app-2' => '5_0_102'
        }
      end

      before(:each) do
        node_attributes['delivery']['project_apps'] = [ 'app-1', 'app-2' ]
      end

      it 'sets the applications as the project applications and returns' \
         ' project application version pinnings' do
        expect(
          described_class.project_application_version_pins_from_env(node, env)
        ).to eq({
          'app-1' => '0_3_562',
          'app-2' => '5_0_102'
        })
      end
    end
  end

  describe '.handle_acceptance_pinnings' do
    let(:acceptance_env_name) { 'acceptance-chef-cookbooks-delivery-truck' }

    let(:project_version) { '= 0.1.2' }
    let(:project_version_in_union) { '= 0.1.1' }

    let(:acceptance_env) do
      env = Chef::Environment.new()
      env.name(acceptance_env_name)
      env.cookbook_versions(acceptance_cookbook_versions)
      env.override_attributes = {
        'applications' => acceptance_application_versions
      }
      env
    end

    let(:union_env) do
      env = Chef::Environment.new()
      env.name('union')
      env.cookbook_versions(union_cookbook_versions)
      env.override_attributes = {
        'applications' => union_application_versions
      }
      env
    end

    before do
      expect(described_class).
        to receive(:fetch_or_create_environment).
        with(acceptance_env_name).
        and_return(acceptance_env)
      expect(described_class).
        to receive(:fetch_or_create_environment).
        with('union').
        and_return(union_env)
      expect(acceptance_env).to receive(:save)
    end

    context 'when the project is a cookbook' do
      let(:acceptance_cookbook_versions) do
        {
          project_name => project_version
        }
      end

      let(:acceptance_application_versions) { {} }

      let(:union_cookbook_versions) do
        {
          project_name => project_version_in_union,
          'cookbook-1' => '= 1.2.0',
          'cookbook-2' => '= 2.0.0'
        }
      end

      let(:union_application_versions) do
        {
          'delivery-app' => '0_3_562'
        }
      end

      let(:cookbook) { instance_double('DeliverySugar::Cookbook') }

      let(:get_all_project_cookbooks) do
        [cookbook]
      end

      before do
        allow(cookbook).to receive(:name).and_return(project_name)
        allow(cookbook).to receive(:version).and_return(project_version)
      end

      it 'copies cookbook and application version pinnings from the union' \
         ' environment to the acceptance environment and updates the cookbook' \
         ' version pinning in the acceptance environment' do
        expected_cookbook_versions = {
          project_name => project_version,
          'cookbook-1' => '= 1.2.0',
          'cookbook-2' => '= 2.0.0'
        }
        expected_application_versions = {
          'delivery-app' => '0_3_562'
        }
        acceptance_env_result =
          described_class.handle_acceptance_pinnings(node, acceptance_env_name, get_all_project_cookbooks)
        expect(acceptance_env_result.cookbook_versions).
          to eq(expected_cookbook_versions)
        expect(acceptance_env_result.override_attributes['applications']).
          to eq(expected_application_versions)
      end
    end

    context 'when the project is an application' do
      let(:acceptance_cookbook_versions) { {} }

      let(:acceptance_application_versions) do
        {
          project_name => project_version
        }
      end

      let(:union_cookbook_versions) do
        {
          'cookbook-1' => '= 1.2.0',
          'cookbook-2' => '= 2.0.0'
        }
      end

      let(:union_application_versions) do
        {
          project_name => project_version_in_union,
          'delivery-app' => '0_3_562'
        }
      end

      before(:each) do
        node.default['delivery']['project_cookbooks'] = []
      end

      let(:get_all_project_cookbooks) do
        []
      end

      it 'copies the cookbook and application version pinnings from the union' \
         ' environment to the acceptance environment and updates the application' \
         ' version pinning in the acceptance environment' do
        expected_cookbook_versions = {
          'cookbook-1' => '= 1.2.0',
          'cookbook-2' => '= 2.0.0'
        }
        expected_application_versions = {
          project_name => project_version,
          'delivery-app' => '0_3_562'
        }
        acceptance_env_result =
          described_class.handle_acceptance_pinnings(node, acceptance_env_name, get_all_project_cookbooks)
        expect(acceptance_env_result.cookbook_versions).
          to eq(expected_cookbook_versions)
        expect(acceptance_env_result.override_attributes['applications']).
          to eq(expected_application_versions)
      end
    end

    context 'a project with cookbooks and applications' do
      let(:project_cookbook_name) { 'delivery-cookbook' }
      let(:project_cookbook_version) { '= 0.3.2' }
      let(:project_cookbook_version_in_union) { '= 0.3.0' }

      let(:project_app_name) { 'delivery-app' }
      let(:project_app_version) { '0_3_562' }
      let(:project_app_version_in_union) { '0_3_561' }

      let(:acceptance_cookbook_versions) do
        {
          project_cookbook_name => project_cookbook_version
        }
      end

      let(:acceptance_application_versions) do
        {
          project_app_name => project_app_version
        }
      end

      let(:union_cookbook_versions) do
        {
          project_cookbook_name => project_cookbook_version_in_union,
          'cookbook-1' => '= 1.2.0',
          'cookbook-2' => '= 2.0.0'
        }
      end

      let(:union_application_versions) do
        {
          project_app_name => project_app_version_in_union,
          'delivery-app' => '0_3_562'
        }
      end

      let(:cookbook) { instance_double('DeliverySugar::Cookbook') }

      let(:get_all_project_cookbooks) do
        [cookbook]
      end

      before(:each) do
        node.default['delivery']['project_cookbooks'] = [project_cookbook_name]
        node.default['delivery']['project_apps'] = [project_app_name]
        allow(cookbook).to receive(:name).and_return(project_cookbook_name)
        allow(cookbook).to receive(:version).and_return(project_cookbook_version)
      end

      it 'copies the cookbook and application version pinnings from the union' \
         ' environment to the acceptance environment and updates the cookbook' \
         ' and application version pinnings in the acceptance environment' do
        expected_cookbook_versions = {
          project_cookbook_name => project_cookbook_version,
          'cookbook-1' => '= 1.2.0',
          'cookbook-2' => '= 2.0.0'
        }
        expected_application_versions = {
          project_app_name => project_app_version,
          'delivery-app' => '0_3_562'
        }
        acceptance_env_result =
          described_class.handle_acceptance_pinnings(node, acceptance_env_name, get_all_project_cookbooks)
        expect(acceptance_env_result.cookbook_versions).
          to eq(expected_cookbook_versions)
        expect(acceptance_env_result.override_attributes['applications']).
          to eq(expected_application_versions)
      end
    end
  end

  describe '.handle_union_pinnings' do
    let(:acceptance_env_name) { 'acceptance-chef-cookbooks-delivery-truck' }

    let(:project_version) { '= 0.1.2' }
    let(:project_version_in_acceptance) { '= 0.1.1' }

    let(:acceptance_env) do
      env = Chef::Environment.new()
      env.name(acceptance_env_name)
      env.cookbook_versions(acceptance_cookbook_versions)
      env.override_attributes = {
        'applications' => acceptance_application_versions
      }
      env
    end

    let(:union_env) do
      env = Chef::Environment.new()
      env.name('union')
      env.cookbook_versions(union_cookbook_versions)
      env.override_attributes = {
        'applications' => union_application_versions
      }
      env
    end

    before(:each) do
      expect(Chef::Environment).
        to receive(:load).
        with(acceptance_env_name).
        and_return(acceptance_env)
      expect(Chef::Environment).
        to receive(:load).
        with('union').
        and_return(union_env)
      expect(union_env).
        to receive(:save)
    end

    let(:passed_in_project_cookbooks) { [] }

    context 'when the project is a cookbook' do
      let(:acceptance_application_versions) { {} }

      let(:acceptance_cookbook_versions) do
        {
          project_name => project_version_in_acceptance        }
      end

      let(:union_application_versions) do
        {
          'an_application' => '= 3.2.0',
          'another_application' => '= 2.2.4'
        }
      end

      let(:union_cookbook_versions) do
        {
          project_name => project_version,
          'an_cookbook' => '= 0.3.1',
          'another_cookbook' => '= 2.0.0'
        }
      end

      context 'when project cookbooks are detected' do
        let(:project_cookbook_name) { "changed_cookbook_that_is_not_in_project_cookbook_attributes" }
        let(:project_cookbook_version) { "= 0.1.0" }

        let(:acceptance_cookbook_versions) do
          {
            project_name => project_version_in_acceptance,
            project_cookbook_name => project_cookbook_version
          }
        end

        let(:project_cookbook) { instance_double('DeliverySugar::Cookbook') }

        before do
          allow(project_cookbook).to receive(:name).and_return(project_cookbook_name)
          allow(project_cookbook).to receive(:version).and_return(project_cookbook_version)
        end

        it 'copies cookbook version pinnings from the acceptance environment' \
           ' to the union environment' do
          expected_union_cookbook_versions =
            union_cookbook_versions.dup # copy, don't mutate incoming test state
          expected_union_cookbook_versions[project_name] =
            project_version_in_acceptance
          expected_union_cookbook_versions[project_cookbook_name] =
            project_cookbook_version

          union_env_result =
            described_class.handle_union_pinnings(node, acceptance_env_name, [project_cookbook])

          expect(union_env_result.cookbook_versions).
            to eq(expected_union_cookbook_versions)
          expect(union_env_result.override_attributes['applications']).
            to eq(union_application_versions)
        end

        it 'does not update pinnings if change id has already been updated' do
          first_union_env_result =
            described_class.handle_union_pinnings(node, acceptance_env_name, [project_cookbook])

          modified_acceptance_env = Chef::Environment.new()
          modified_acceptance_env.name(acceptance_env_name)
          modified_acceptance_env.cookbook_versions(
              acceptance_cookbook_versions.merge(new_cookbook: '1.1.1'))

          expect(described_class).
            to receive(:fetch_or_create_environment).
            with(acceptance_env_name).
            and_return(modified_acceptance_env)
          expect(described_class).
            to receive(:fetch_or_create_environment).
            with('union').
            and_return(first_union_env_result)

          seccond_union_env_result =
            described_class.handle_union_pinnings(node, acceptance_env_name, [project_cookbook])
          expect(first_union_env_result).to eq(seccond_union_env_result)
        end
      end

      describe 'cached project metadata' do
        context 'when no cached project metadata exists' do
          # This case will happen once when the build cookbook is upgraded
          # to pull in a version of delivery-truck which has this feature
          it 'caches the project metadata' do
            expected_project_metadata = {
              project_name => {
                'cookbooks' => [project_name],
                # You only populate if acceptance_env.override_attributes['applications']
                # actually contains an application named `project_name`, which is
                # not the case in this test.
                'applications' => []
              }
            }

            union_env_result =
              described_class.handle_union_pinnings(node, acceptance_env_name, passed_in_project_cookbooks)

            expect(union_env_result.default_attributes['delivery']['project_artifacts']).
              to eq(expected_project_metadata)
          end
        end

        context 'when the project is new' do
          let(:projects_metadata) do
            {
              'project-foo' => {
                'cookbooks' => [],
                'applications' => ['project-foo-app']
              },
              'project-bar' => {
                'cookbooks' => ['project-bar-1', 'project-bar-1'],
                'applications' => ['project-bar-app']
              }
            }
          end

          before(:each) do
            union_env.default_attributes = {
              'delivery' => { 'project_artifacts' => projects_metadata }
            }
          end

          it 'adds the project cookbook to the cached projects metadata' do
            expected_projects_metadata = projects_metadata.dup
            expected_projects_metadata[project_name] = {
              'cookbooks' => [project_name],
              'applications' => []
            }

            union_env_result =
              described_class.handle_union_pinnings(node, acceptance_env_name, passed_in_project_cookbooks)

            expect(union_env_result.default_attributes['delivery']['project_artifacts']).
              to eq(expected_projects_metadata)
          end
        end

        context 'when the project metadata changes' do
          let(:projects_metadata) do
            {
              project_name => {
                'cookbooks' => ["#{project_name}-1", "#{project_name}-2"],
                'applications' => []
              }
            }
          end

          before(:each) do
            union_env.default_attributes = {
              'delivery' => { 'project_artifacts' => projects_metadata }
            }
          end

          it 'updates the project metadata in the cache' do
            expected_projects_metadata = projects_metadata.dup
            expected_projects_metadata[project_name] = {
              'cookbooks' => [project_name],
              'applications' => []
            }

            union_env_result =
              described_class.handle_union_pinnings(node, acceptance_env_name, passed_in_project_cookbooks)

            expect(union_env_result.default_attributes['delivery']['project_artifacts']).
              to eq(expected_projects_metadata)
          end
        end
      end
    end

    context 'when the project is an application' do
      let(:acceptance_application_versions) do
        {
          project_name => project_version_in_acceptance
        }
      end

      let(:acceptance_cookbook_versions) do
        {
          project_name => project_version
        }
      end

      let(:union_application_versions) do
        {
          project_name => project_version,
          'an_application' => '= 3.2.0',
          'another_application' => '= 2.2.4'
        }
      end

      let(:union_cookbook_versions) do
        {
          'an_cookbook' => '= 0.3.1',
          'another_cookbook' => '= 2.0.0'
        }
      end

      before(:each) do
        node.default['delivery']['project_cookbooks'] = nil
      end

      context "cached project metadata" do
        let(:acceptance_env) do
          env = Chef::Environment.new()
          env.name(acceptance_env_name)
          env.cookbook_versions(acceptance_cookbook_versions)
          env.override_attributes = {
            'applications' => {
              'app1' => '= 1.0.0',
              'app2' => '= 1.0.0',
              'app3' => '= 1.0.0'
            }
          }
          env
        end

        it "saved all app names for the current project that have valid values" \
          "in the acceptance env" do
          app_names = ["app1", "app2", "app3"]
          node.default['delivery']['project_apps'] = app_names

          expected_project_metadata = {
            project_name => {
              'cookbooks' => [project_name],
              'applications' => app_names
            }
          }

          union_env_result =
            described_class.handle_union_pinnings(node, acceptance_env_name, passed_in_project_cookbooks)

          expect(union_env_result.default_attributes['delivery']['project_artifacts']).
            to eq(expected_project_metadata)
        end
      end

      it 'copies application version pinnings from the acceptance environment' \
         ' to the union environment' do
        expected_union_application_versions = union_application_versions.dup
        expected_union_application_versions[project_name] =
          project_version_in_acceptance

        union_env_result =
          described_class.handle_union_pinnings(node, acceptance_env_name, passed_in_project_cookbooks)

        expect(node['delivery']['project_apps']).to eq([project_name])
        expect(union_env_result.cookbook_versions).
          to eq(union_cookbook_versions)
        expect(union_env_result.override_attributes['applications']).
          to eq(expected_union_application_versions)
      end
    end

    context 'a project with applications and cookbooks' do
      let(:project_app_name) { 'delivery-app' }
      let(:project_app_version) { '0_3_562' }
      let(:project_app_version_in_acceptance) { '0_3_563' }

      let(:project_cookbook_names) { ['delivery-cookbook-1', 'delivery-cookbook-2'] }
      let(:project_cookbook_versions) { ['= 0.3.0', '= 1.0.2'] }
      let(:project_cookbook_versions_in_acceptance) { ['= 0.3.2', '= 1.0.4'] }

      let(:acceptance_application_versions) do
        {
          project_app_name => project_app_version_in_acceptance
        }
      end

      let(:acceptance_cookbook_versions) do
        {
          project_cookbook_names[0] => project_cookbook_versions_in_acceptance[0],
          project_cookbook_names[1] => project_cookbook_versions_in_acceptance[1],
        }
      end

      let(:union_application_versions) do
        {
          project_app_name => project_app_version,
          'an_application' => '= 3.2.0',
          'another_application' => '= 2.2.4'
        }
      end

      let(:union_cookbook_versions) do
        {
          project_cookbook_names[0] => project_cookbook_versions[0],
          project_cookbook_names[1] => project_cookbook_versions[1],
          'an_cookbook' => '= 0.3.1',
          'another_cookbook' => '= 2.0.0'
        }
      end

      before(:each) do
        node.default['delivery']['project_cookbooks'] = project_cookbook_names
        node.default['delivery']['project_apps'] = [project_app_name]
      end

      describe "cached project metadata" do
        it "saved all apps and cookbooks for the current project" do
            expected_project_metadata = {
              project_name => {
                'cookbooks' => project_cookbook_names,
                'applications' => [project_app_name]
              }
            }

            union_env_result =
              described_class.handle_union_pinnings(node, acceptance_env_name, passed_in_project_cookbooks)

            expect(union_env_result.default_attributes['delivery']['project_artifacts']).
              to eq(expected_project_metadata)
        end
      end

      it 'copies cookbook and application version pinnings from the acceptance' \
         ' environment to the union environment' do
        expected_union_cookbook_versions = union_cookbook_versions.dup
        expected_union_cookbook_versions[project_cookbook_names[0]] =
          project_cookbook_versions_in_acceptance[0]
        expected_union_cookbook_versions[project_cookbook_names[1]] =
          project_cookbook_versions_in_acceptance[1]

        expected_union_application_versions = union_application_versions.dup
        expected_union_application_versions[project_app_name] =
          project_app_version_in_acceptance

        union_env_result =
          described_class.handle_union_pinnings(node, acceptance_env_name, [])

        expect(union_env_result.cookbook_versions).
          to eq(union_cookbook_versions)
        expect(union_env_result.override_attributes['applications']).
          to eq(expected_union_application_versions)
      end
    end
  end

  describe '.handle_rehearsal_pinnings' do
    let(:rehearsal_applications) do
      {
        'app_1' => '0_3_562',
        'app_2' => '1_0_205',
        'no_longer_supported_app' => '0_0_50'
      }
    end

    let(:rehearsal_cookbook_versions) do
      {
        'cookbook_1' => '= 1.2.2',
        'cookbook_2' => '= 0.0.9',
        'no_longer_supported_cookbook' => '= 2.3.0'
      }
    end

    let(:rehearsal_default_attributes) do
      {
        'delivery' => { 'project_artifacts' => {} }
      }
    end

    let(:union_applications) do
      {
        'app_1' => '0_3_563',
        'app_2' => '1_0_206',
        'new_app' => '0_0_1'
      }
    end

    let(:union_cookbook_versions) do
      {
        'cookbook_1' => '= 1.2.3',
        'cookbook_2' => '= 0.1.0',
        'new_cookbook' => '= 0.1.0'
      }
    end

    let(:union_default_attributes) do
      {
        'delivery' => {
          'union_changes' => [
             change_id
          ],
          'project_artifacts' => {
            'other_project_1' => {
              'cookbooks' => [
                'cookbook_1'
              ],
              'applications' => [
                  'app_1'
              ]
            },
            'other_project_2' => {
              'cookbooks' => [
                'cookbook_2'
              ],
              'applications' => [
                'app_2'
              ]
            },
            'new_project' => {
              'cookbooks' => [
                'new_cookbook'
              ],
              'applications' => [
                'new_app'
              ]
            }
          }
        }
      }
    end

    let(:rehearsal_env) do
      env = Chef::Environment.new
      env.name('rehearsal')
      env.cookbook_versions(rehearsal_cookbook_versions)
      env.default_attributes = rehearsal_default_attributes
      env.override_attributes = {
        'applications' => rehearsal_applications
      }
      env
    end

    let(:union_env) do
      env = Chef::Environment.new
      env.name('union')
      env.cookbook_versions(union_cookbook_versions)
      env.default_attributes = union_default_attributes
      env.override_attributes = {
        'applications' => union_applications
      }
      env
    end

    before(:each) do
      expect(Chef::Environment).
        to receive(:load).
        with('union').
        and_return(union_env)
      expect(Chef::Environment).
        to receive(:load).
        with('rehearsal').
        and_return(rehearsal_env)
      expect(rehearsal_env).
        to receive(:save)
      expect(union_env).to receive(:save)
    end

    it 'removes the change from the union environment change list' do
      expect(DeliveryTruck::DeliveryApiClient).
        to receive(:blocked_projects).
        with(node).
        and_return([])

      described_class.handle_rehearsal_pinnings(node)
      expect(union_env.default_attributes['delivery']['union_changes']).to eql([])
    end

    context 'a project with a single cookbook' do
      let(:project_version_in_rehearsal) { "= 2.2.0" }
      let(:project_version_in_union) { "= 2.2.2" }

      let(:rehearsal_applications) { {} }
      let(:rehearsal_cookbook_versions) do
        {
          project_name => project_version_in_rehearsal,
          'cookbook_1' => '= 0.3.0',
          'cookbook_2' => '= 1.4.1'
        }
      end

      let(:union_applications) { {} }
      let(:union_cookbook_versions) do
        {
          project_name => project_version_in_union,
          'cookbook_1' => '= 0.3.1',
          'cookbook_2' => '= 1.4.1'
        }
      end
      let(:rehearsal_default_attributes) do
        {
          'delivery' => {
            'project_artifacts' => {
              project_name => {
                'cookbooks' => [
                  project_name,
                  'vestigal_cookbook'
                ],
                'applications' => []
              },
              'other_project_1' => {
                'cookbooks' => [
                  'cookbook_1',
                  'outdated_cookbook'
                ],
                'applications' => []
              },
              'other_project_2' => {
                'cookbooks' => [
                  'cookbook_2'
                ],
                'applications' => []
              }
            }
          }
        }
      end

      let(:union_default_attributes) do
        {
          'delivery' => {
            'project_artifacts' => {
              project_name => {
                'cookbooks' => [
                  project_name
                ],
                'applications' => []
              },
              'other_project_1' => {
                'cookbooks' => [
                  'cookbook_1'
                ],
                'applications' => []
              },
              'other_project_2' => {
                'cookbooks' => [
                  'cookbook_2'
                ],
                'applications' => []
              }
            }
          }
        }
      end

      context 'when the project is blocked' do
        before(:each) do
          expect(DeliveryTruck::DeliveryApiClient).
            to receive(:blocked_projects).
            with(node).
            and_return([project_name])
        end

        it 'does not update the version pinning for the cookbook in the' \
           ' rehearsal environment' do
          expected_cookbook_versions = {
            project_name => project_version_in_rehearsal,
            'cookbook_1' => '= 0.3.1',
            'cookbook_2' => '= 1.4.1'
          }

          expected_applications = rehearsal_applications.dup
          expected_default_attributes = {
            'delivery' => {
              'project_artifacts' => {
                project_name => {
                  'cookbooks' => [
                    project_name,
                    'vestigal_cookbook'
                  ],
                  'applications' => []
                },
                'other_project_1' => {
                  'cookbooks' => [
                    'cookbook_1'
                  ],
                  'applications' => []
                },
                'other_project_2' => {
                  'cookbooks' => [
                    'cookbook_2'
                  ],
                  'applications' => []
                }
              }
            }
          }

          rehearsal_env_result = described_class.handle_rehearsal_pinnings(node)

          expect(rehearsal_env_result.cookbook_versions).
            to eq(expected_cookbook_versions)
          expect(rehearsal_env_result.default_attributes).
            to eq(expected_default_attributes)
          expect(rehearsal_env_result.override_attributes['applications']).
            to eq(expected_applications)
        end

        # maybe we want to test when node['delivery']['project_cookbooks'] is set
        # context 'when the project ships multiple cookbooks' do
      end

      context 'when the project is not blocked' do
        let(:blocked_projects) { [] }
        before(:each) do
          expect(DeliveryTruck::DeliveryApiClient).
            to receive(:blocked_projects).
            with(node).
            and_return(blocked_projects)
        end

        context 'nothing is blocked' do
          let(:blocked_projects) { [] }

          let(:union_applications) do
            {
              "unknown_application" => "1.1.1",
              "other_application" => "0.0.1"
            }
          end

          let(:union_cookbook_versions) do
              {
                project_name => project_version_in_union,
                'cookbook_1' => '= 0.3.1',
                'cookbook_2' => '= 1.4.1',
                'unknown_cookbook' => '= 110.100.100'
              }
          end

          it 'moves all version pinnings from union to rehersal' do
            expected_cookbook_versions = union_cookbook_versions.dup
            expected_applications = union_applications.dup
            expected_default_attributes = union_default_attributes.dup

            rehearsal_env_result = described_class.handle_rehearsal_pinnings(node)

            expect(rehearsal_env_result.cookbook_versions).
              to eq(expected_cookbook_versions)
            expect(rehearsal_env_result.default_attributes).
              to eq(expected_default_attributes)
            expect(rehearsal_env_result.override_attributes['applications']).
              to eq(expected_applications)
          end
        end

        context 'other project is blocked' do
          let(:blocked_projects) { ['other_project_1'] }

          let(:union_default_attributes) do
            {
              'delivery' => {
                'project_artifacts' => {
                  project_name => {
                    'cookbooks' => [
                      project_name
                    ],
                    'applications' => []
                  },
                  'other_project_1' => {
                    'cookbooks' => [
                      'cookbook_1'
                    ],
                    'applications' => []
                  },
                  'other_project_2' => {
                    'cookbooks' => [
                      'cookbook_2'
                    ],
                    'applications' => []
                  }
                }
              }
            }
          end

          it 'does not update the version pinning for the impacted cookbook in' \
             '  the rehearsal environment' do
           expected_cookbook_versions = {
                     project_name => project_version_in_union,
                     'cookbook_1' => '= 0.3.0',
                     'cookbook_2' => '= 1.4.1' }
           expected_applications = union_applications.dup
           expected_default_attributes = {
               'delivery' => {
                 'project_artifacts' => {
                   project_name => {
                     'cookbooks' => [
                       project_name
                     ],
                     'applications' => []
                   },
                   'other_project_1' => {
                       'cookbooks' => [
                           'cookbook_1',
                           'outdated_cookbook'
                       ],
                       'applications' => []
                   },
                   'other_project_2' => {
                     'cookbooks' => [
                       'cookbook_2'
                     ],
                     'applications' => []
                   }
                 }
               }
             }

           rehearsal_env_result = described_class.handle_rehearsal_pinnings(node)

           expect(rehearsal_env_result.cookbook_versions).
             to eq(expected_cookbook_versions)
           expect(rehearsal_env_result.default_attributes).
             to eq(expected_default_attributes)
           expect(rehearsal_env_result.override_attributes['applications']).
             to eq(expected_applications)
          end
        end
      end
    end

    context 'a project with several cookbooks' do
      let(:rehearsal_applications) { {} }
      let(:rehearsal_cookbook_versions) do
        {
          'delivery_1' => '= 0.0.0',
          'delivery_2' => '= 1.0.0',
          'cookbook_1' => '= 0.3.0',
          'cookbook_2' => '= 1.4.1'
        }
      end
      let(:rehearsal_default_attributes) { {
          'delivery' => { 'project_artifacts' => {} }
      } }

      let(:union_applications) { {} }
      let(:union_cookbook_versions) do
        {
          'delivery_1' => '= 0.0.1',
          'delivery_2' => '= 1.0.1',
          'cookbook_1' => '= 0.3.1',
          'cookbook_2' => '= 1.4.1'
        }
      end

      let(:union_default_attributes) do
        {
          'delivery' => {
            'project_artifacts' => {
              project_name => {
                'cookbooks' => [
                  'delivery_1',
                  'delivery_2'
                ],
                'applications' => []
              },
              'other_project_1' => {
                'cookbooks' => [
                  'cookbook_1'
                ],
                'applications' => []
              },
              'other_project_2' => {
                'cookbooks' => [
                  'cookbook_2'
                ],
                'applications' => []
              }
            }
          }
        }
      end

      let(:blocked_projects) { [] }
      let(:node_attributes) do
        {
          'delivery' => {
            'change' => {
              'project' => project_name
            },
            'project_cookbooks' => ['delivery_1', 'delivery_2']
          }
        }
      end
      before(:each) do
        expect(DeliveryTruck::DeliveryApiClient).
          to receive(:blocked_projects).
          with(node).
          and_return(blocked_projects)
      end

      context 'nothing is blocked' do
        let(:blocked_projects) { [] }

        it 'updates the version pinning for the cookbook in the rehearsal' \
          ' environment' do

         expected_cookbook_versions = union_cookbook_versions.dup
         expected_applications = union_applications.dup
         expected_default_attributes = union_default_attributes.dup

         rehearsal_env_result = described_class.handle_rehearsal_pinnings(node)

         expect(rehearsal_env_result.cookbook_versions).
           to eq(expected_cookbook_versions)
         expect(rehearsal_env_result.default_attributes).
           to eq(expected_default_attributes)
         expect(rehearsal_env_result.override_attributes['applications']).
           to eq(expected_applications)
        end

        context 'when the rehersal delivery attribute has not been initialized' do
          let(:rehearsal_default_attributes) { {} }

          it 'properly initializes the hash and the promotes as usual' do
            expected_cookbook_versions = union_cookbook_versions.dup
            expected_applications = union_applications.dup
            expected_default_attributes = union_default_attributes.dup

            rehearsal_env_result = described_class.handle_rehearsal_pinnings(node)

            expect(rehearsal_env_result.cookbook_versions).
              to eq(expected_cookbook_versions)
            expect(rehearsal_env_result.default_attributes).
              to eq(expected_default_attributes)
            expect(rehearsal_env_result.override_attributes['applications']).
              to eq(expected_applications)
          end
        end
      end

      context 'the project is blocked' do
        let(:blocked_projects) { [project_name] }
        it "does not update this project's project cookbooks but does update" \
           "other cookbooks" do
         expected_cookbook_versions = union_cookbook_versions.dup
         expected_cookbook_versions['delivery_1']= '= 0.0.0'
         expected_cookbook_versions['delivery_2']= '= 1.0.0'

         expected_applications = union_applications.dup
         expected_default_attributes = rehearsal_default_attributes.dup

         rehearsal_env_result = described_class.handle_rehearsal_pinnings(node)

         expect(rehearsal_env_result.cookbook_versions).
           to eq(expected_cookbook_versions)
         expect(rehearsal_env_result.default_attributes).
           to eq(expected_default_attributes)
         expect(rehearsal_env_result.override_attributes['applications']).
           to eq(expected_applications)
        end
      end
    end

    context 'a project with several cookbooks and applications' do
      let(:rehearsal_applications) do
        {
          'our_app_1' => '= 2.0.0',
          'our_app_2' => '= 3.0.0',
          'app_1' => '= 0.3.0',
          'app_2' => '= 1.4.1'
        }
      end
      let(:rehearsal_cookbook_versions) do
        {
          'our_cookbook_1' => '= 0.0.0',
          'our_cookbook_2' => '= 1.0.0',
          'cookbook_1' => '= 0.3.0',
          'cookbook_2' => '= 1.4.1'
        }
      end

      let(:union_applications) do
        {
          'our_app_1' => '= 2.0.1',
          'our_app_2' => '= 3.0.1',
          'app_1' => '= 0.3.1',
          'app_2' => '= 1.4.2'
        }
      end
      let(:union_cookbook_versions) do
        {
          'our_cookbook_1' => '= 0.0.1',
          'our_cookbook_2' => '= 1.0.1',
          'cookbook_1' => '= 0.3.1',
          'cookbook_2' => '= 1.4.1'
        }
      end

      let(:union_default_attributes) do
        {
          'delivery' => {
            'project_artifacts' => {
              project_name => {
                'cookbooks' => [
                  'our_cookbook_1',
                  'our_cookbook_2'
                ],
                'applications' => [
                  'our_app_1',
                  'our_app_2',
                ]
              },
              'other_project_1' => {
                'cookbooks' => [
                  'cookbook_1',
                ],
                'applications' => [ 'app_1' ]
              },
              'other_project_2' => {
                'cookbooks' => [
                  'cookbook_2'
                ],
                'applications' => [ 'app_2' ]
              }
            }
          }
        }
      end

      let(:rehearsal_default_attributes) do
        union_default_attributes.dup
      end

      context 'when the project is blocked' do
        before(:each) do
          expect(DeliveryTruck::DeliveryApiClient).
            to receive(:blocked_projects).
            with(node).
            and_return([project_name])
        end

        it 'does not update the version pinning for the cookbook or apps in the' \
           ' rehearsal environment' do
          expected_cookbook_versions = {
            'our_cookbook_1' => '= 0.0.0',
            'our_cookbook_2' => '= 1.0.0',
            'cookbook_1' => '= 0.3.1',
            'cookbook_2' => '= 1.4.1'
          }

          expected_applications = {
            'our_app_1' => '= 2.0.0',
            'our_app_2' => '= 3.0.0',
            'app_1' => '= 0.3.1',
            'app_2' => '= 1.4.2'
          }

          rehearsal_env_result = described_class.handle_rehearsal_pinnings(node)

          expect(rehearsal_env_result.cookbook_versions).
            to eq(expected_cookbook_versions)
          expect(rehearsal_env_result.override_attributes['applications']).
            to eq(expected_applications)
        end

        # maybe we want to test when node['delivery']['project_cookbooks'] is set
        # context 'when the project ships multiple cookbooks' do
      end

      context 'when a different project is blocked' do
        before(:each) do
          expect(DeliveryTruck::DeliveryApiClient).
            to receive(:blocked_projects).
            with(node).
            and_return(['other_project_1'])
        end

        it 'does not update the version pinning for the cookbook or apps in the' \
           ' rehearsal environment' do
          expected_cookbook_versions = {
            'our_cookbook_1' => '= 0.0.1',
            'our_cookbook_2' => '= 1.0.1',
            'cookbook_1' => '= 0.3.0',
            'cookbook_2' => '= 1.4.1'
          }

          expected_applications = {
            'our_app_1' => '= 2.0.1',
            'our_app_2' => '= 3.0.1',
            'app_1' => '= 0.3.0',
            'app_2' => '= 1.4.2'
          }

          rehearsal_env_result = described_class.handle_rehearsal_pinnings(node)

          expect(rehearsal_env_result.cookbook_versions).
            to eq(expected_cookbook_versions)
          expect(rehearsal_env_result.override_attributes['applications']).
            to eq(expected_applications)
        end

        # maybe we want to test when node['delivery']['project_cookbooks'] is set
        # context 'when the project ships multiple cookbooks' do
      end

    end
  end

  describe '.handle_delivered_pinnings' do
    let(:previous_stage_env_name) { 'rehearsal' }

    let(:previous_stage_applications) do
      {
        'app_1' => '0_3_563',
        'app_2' => '1_0_206',
        'new_app' => '0_0_1'
      }
    end

    let(:previous_stage_cookbook_versions) do
      {
        'cookbook_1' => '= 1.2.3',
        'cookbook_2' => '= 0.1.0',
        'new_cookbook' => '= 0.1.0'
      }
    end

    let(:previous_stage_default_attributes) do
      {
        'foo' => 'bar'
      }
    end

    let(:previous_stage_env) do
      env = Chef::Environment.new()
      env.name(previous_stage_env_name)
      env.cookbook_versions(previous_stage_cookbook_versions)
      env.default_attributes = previous_stage_default_attributes
      env.override_attributes = {
        'applications' => previous_stage_applications
      }
      env
    end

    let(:current_stage_env_name) { 'delivered' }

    let(:current_stage_applications) do
      {
        'app_1' => '0_3_562',
        'app_2' => '1_0_205',
        'no_longer_supported_app' => '0_0_50'
      }
    end

    let(:current_stage_cookbook_versions) do
      {
        'cookbook_1' => '= 1.2.2',
        'cookbook_2' => '= 0.0.9',
        'no_longer_supported_cookbook' => '= 2.3.0'
      }
    end

    let(:current_stage_default_attributes) do
      {
        'foo' => 'baz'
      }
    end

    let(:current_stage_env) do
      env = Chef::Environment.new()
      env.name(current_stage_env_name)
      env.cookbook_versions(current_stage_cookbook_versions)
      env.default_attributes = current_stage_default_attributes
      env.override_attributes = {
        'applications' => current_stage_applications
      }
      env
    end

    before(:each) do
      expect(Chef::Environment).
        to receive(:load).
        with(previous_stage_env_name).
        and_return(previous_stage_env)
      expect(Chef::Environment).
        to receive(:load).
        with(current_stage_env_name).
        and_return(current_stage_env)
      expect(current_stage_env).
        to receive(:save)
    end

    it 'merges all cookbook and application version pinnings from the previous' \
       ' environment to the current environment' do
      expected_cookbook_versions = previous_stage_cookbook_versions.dup

      expected_applications = previous_stage_applications.dup

      expected_default_attributes = previous_stage_default_attributes.dup

      current_stage_env_result =
        described_class.handle_delivered_pinnings(node)

      expect(current_stage_env_result.cookbook_versions).
        to eq(expected_cookbook_versions)
      expect(current_stage_env_result.default_attributes).
        to eq(expected_default_attributes)
      expect(current_stage_env_result.override_attributes['applications']).
        to eq(expected_applications)
    end
  end

end
