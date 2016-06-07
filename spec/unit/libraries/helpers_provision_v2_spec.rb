require 'spec_helper'

describe DeliveryTruck::Helpers::ProvisionV2 do
  let(:project_name) { 'delivery' }
  let(:change_id) { 'change-id' }

  let(:cookbook_name) { 'delivery-cookbook' }
  let(:cookbook_version) { '= 0.1.2' }
  let(:cookbook_version_in_acceptance) { '= 0.1.1' }
  let(:cookbook_version_in_union) { '= 0.1.0' }

  let(:app_name) { 'delivery-app' }
  let(:app_version) { '0_3_562' }
  let(:app_version_in_acceptance) { '0_3_561' }
  let(:app_version_in_union) { '0_3_560' }

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
          'change_id' => change_id,
          'project' => project_name
        }
      }
    }
  end

  let(:application_versions) do
    {
      'app-1' => '0_3_570',
      'app-2' => '5_0_102'
    }
  end

  let(:application_metadata) do
    {
      'app-1' => {
        'version' => '0_3_570',
        'attributes' => {}
      },
      'app-2' => {
        'version' => '5_0_102',
        'attributes' => {}
      }
    }
  end

  let(:cookbook_versions) do
    {
      'cookbook-1' => '= 1.2.1',
      'cookbook-2' => '= 2.0.0'
    }
  end

  let(:application_versions_2) do
    {
      'app-1' => '0_3_562',
      'app-2' => '5_0_102'
    }
  end

  let(:cookbook_versions_2) do
    {
      'cookbook-1' => '= 1.2.0',
      'cookbook-2' => '= 2.0.0'
    }
  end

  let(:application_versions_3) do
    {
      'app-1' => '0_3_560',
      'app-2' => '5_0_98'
    }
  end

  let(:cookbook_versions_3) do
    {
      'cookbook-1' => '= 1.1.9',
      'cookbook-2' => '= 2.0.0',
      'cookbook-3' => '= 3.4.5'
    }
  end

  describe '.handle_acceptance_pinnings' do
    let(:acceptance_env_name) { 'acceptance-chef-cookbooks-delivery-truck' }

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

    let(:promotion_data_bag_item) do
      pins = Chef::DataBagItem.new()
      pins.raw_data = {
        'id' => 'change-id',
        'project_cookbooks' => new_cookbook_versions,
        'applications' => new_application_metadata
      }
      pins
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
      expect(described_class).
        to receive(:fetch_promotion_data).
        and_return(promotion_data_bag_item)
    end

    context 'when the project is a cookbook' do
      let(:new_cookbook_versions) { {project_name => cookbook_version} }
      let(:new_application_metadata) { {} }

      let(:acceptance_cookbook_versions) do
        cookbook_versions_2.merge({project_name => cookbook_version_in_acceptance})
      end
      let(:acceptance_application_versions) { {} }

      let(:union_cookbook_versions) do
        cookbook_versions_3.merge({project_name => cookbook_version_in_union})
      end
      let(:union_application_versions) { application_versions_3 }


      it 'copies cookbook and application version pinnings from the union' \
         ' environment to the acceptance environment and updates the cookbook' \
         ' version pinning in the acceptance environment' do
        expected_cookbook_versions = acceptance_cookbook_versions.
          merge(union_cookbook_versions).
          merge({project_name => cookbook_version})
        expected_application_versions = acceptance_application_versions.
          merge(union_application_versions)

        acceptance_env_result =
          described_class.handle_acceptance_pinnings(node, acceptance_env_name)
        expect(acceptance_env_result.cookbook_versions).
          to eq(expected_cookbook_versions)
        expect(acceptance_env_result.override_attributes['applications']).
          to eq(expected_application_versions)
      end
    end

    context 'when the project is an application' do
      let(:new_cookbook_versions) { {} }
      let(:new_application_metadata) do
        {
          project_name => {
            'version' => app_version,
            'attributes' => {}
          }
        }
      end

      let(:acceptance_cookbook_versions) { cookbook_versions_2 }
      let(:acceptance_application_versions) { {project_name => app_version_in_acceptance} }

      let(:union_cookbook_versions) { cookbook_versions_3 }
      let(:union_application_versions) do
        application_versions_3.merge({project_name => app_version_in_union})
      end

      it 'copies the cookbook and application version pinnings from the union' \
         ' environment to the acceptance environment and updates the application' \
         ' version pinning in the acceptance environment' do
        expected_cookbook_versions = acceptance_cookbook_versions.
          merge(union_cookbook_versions)
        expected_application_versions = acceptance_application_versions.
          merge(union_application_versions).
          merge({project_name => app_version})

        acceptance_env_result =
          described_class.handle_acceptance_pinnings(node, acceptance_env_name)
        expect(acceptance_env_result.cookbook_versions).
          to eq(expected_cookbook_versions)
        expect(acceptance_env_result.override_attributes['applications']).
          to eq(expected_application_versions)
      end
    end

    context 'a project with cookbooks and applications' do
      let(:new_cookbook_versions) { {cookbook_name => cookbook_version} }
      let(:new_application_metadata) do
        {
          app_name => {
            'version' => app_version,
            'attributes' => {}
          }
        }
      end

      let(:acceptance_cookbook_versions) do
        cookbook_versions_2.merge({cookbook_name => cookbook_version_in_acceptance})
      end
      let(:acceptance_application_versions) { {app_name => app_version_in_acceptance} }

      let(:union_cookbook_versions) do
        cookbook_versions_3.merge({cookbook_name => cookbook_version_in_union})
      end
      let(:union_application_versions) do
        application_versions_3.merge({app_name => app_version_in_union})
      end

      before(:each) do
        node.default['delivery']['project_cookbooks'] = [cookbook_name]
        node.default['delivery']['project_apps'] = [app_name]
      end

      it 'copies the cookbook and application version pinnings from the union' \
         ' environment to the acceptance environment and updates the cookbook' \
         ' and application version pinnings in the acceptance environment' do
        expected_cookbook_versions = acceptance_cookbook_versions.
          merge(union_cookbook_versions).
          merge({cookbook_name => cookbook_version})
        expected_application_versions = acceptance_application_versions.
          merge(union_application_versions).
          merge({app_name => app_version})

        acceptance_env_result =
          described_class.handle_acceptance_pinnings(node, acceptance_env_name)
        expect(acceptance_env_result.cookbook_versions).
          to eq(expected_cookbook_versions)
        expect(acceptance_env_result.override_attributes['applications']).
          to eq(expected_application_versions)
      end
    end
  end

  describe '.handle_union_pinnings' do
    let(:new_cookbook_versions) { {project_name => cookbook_version} }

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

    let(:promotion_data_bag_item) do
      pins = Chef::DataBagItem.new()
      pins.raw_data = {
        'id' => 'change-id',
        'project_cookbooks' => new_cookbook_versions,
        'applications' => new_application_metadata
      }
      pins
    end

    before(:each) do
      expect(Chef::Environment).
        to receive(:load).
        with('union').
        and_return(union_env)
      expect(union_env).
        to receive(:save)
      expect(described_class).
        to receive(:fetch_promotion_data).
        and_return(promotion_data_bag_item)

      node.default['delivery']['project_apps'] = application_metadata.keys
    end

    context 'when the project is a cookbook' do
      let(:new_cookbook_versions) { {project_name => cookbook_version} }
      let(:new_application_metadata) { {} }

      let(:union_cookbook_versions) do
        cookbook_versions_3.merge({project_name => cookbook_version_in_union})
      end
      let(:union_application_versions) { application_versions_3 }

      context 'when project cookbooks are detected' do
        let(:project_cookbook_name) { "changed_cookbook_that_is_not_in_project_cookbook_attributes" }
        let(:project_cookbook_version) { "= 0.1.0" }

        let(:new_cookbook_versions) do
          {
            project_name => cookbook_version_in_acceptance,
            project_cookbook_name => project_cookbook_version
          }
        end

        it 'copies cookbook version pinnings from the promotion object' \
           ' to the union environment' do
          expected_union_cookbook_versions =
            union_cookbook_versions.dup # copy, don't mutate incoming test state
          expected_union_cookbook_versions[project_name] =
            cookbook_version_in_acceptance
          expected_union_cookbook_versions[project_cookbook_name] =
            project_cookbook_version

          union_env_result =
            described_class.handle_union_pinnings(node)

          expect(union_env_result.cookbook_versions).
            to eq(expected_union_cookbook_versions)
          expect(union_env_result.override_attributes['applications']).
            to eq(union_application_versions)
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
              described_class.handle_union_pinnings(node)

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
              described_class.handle_union_pinnings(node)

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
              described_class.handle_union_pinnings(node)

            expect(union_env_result.default_attributes['delivery']['project_artifacts']).
              to eq(expected_projects_metadata)
          end
        end
      end
    end

    context 'when the project is an application' do
      let(:new_cookbook_versions) { {} }
      let(:new_application_metadata) do
        {
          project_name => {
            'version' => app_version,
            'attributes' => {}
          },
          'app1' => {
            'version' => '1.0.0',
            'attributes' => {},
          },
          'app2' => {
            'version' => '1.0.0',
            'attributes' => {}
          },
          'app3' => {
            'version' => '1.0.0',
            'attributes' => {}
          }
        }
      end

      let(:new_application_versions) do
        {
          project_name => app_version,
          'app1' => '1.0.0',
          'app2' => '1.0.0',
          'app3' => '1.0.0'
        }
      end

      let(:union_cookbook_versions) { cookbook_versions_3 }
      let(:union_application_versions) do
        application_versions_3.merge(new_application_versions)
      end

      context "cached project metadata" do
        it "saved all app names for the current project that have valid values" \
          "in the promotion data" do

          expected_project_metadata = {
            project_name => {
              'cookbooks' => [],
              'applications' => new_application_versions.keys
            }
          }

          union_env_result =
            described_class.handle_union_pinnings(node)

          expect(union_env_result.default_attributes['delivery']['project_artifacts']).
            to eq(expected_project_metadata)
        end
      end

      it 'copies application version pinnings from the promotion data' \
         ' to the union environment' do
        expected_union_application_versions = union_application_versions.
          merge(new_application_versions)

        union_env_result =
          described_class.handle_union_pinnings(node)

        expect(union_env_result.cookbook_versions).
          to eq(union_cookbook_versions)
        expect(union_env_result.override_attributes['applications']).
          to eq(expected_union_application_versions)
      end
    end

    context 'a project with applications and cookbooks' do
      let(:new_cookbook_versions) do
        cookbook_versions.merge({cookbook_name => cookbook_version})
      end
      let(:new_application_metadata) do
        application_metadata.merge({
          app_name => {
            'version' => app_version,
            'attributes' => {}
          }
        })
      end
      let(:new_application_versions) do
        application_versions.merge({app_name => app_version})
      end

      let(:acceptance_cookbook_versions) do
        cookbook_versions_2.merge({cookbook_name => cookbook_version_in_acceptance})
      end
      let(:acceptance_application_versions) do
        application_versions_2.merge({app_name => app_version_in_acceptance})
      end

      let(:union_cookbook_versions) do
        cookbook_versions_3.merge({cookbook_name => cookbook_version_in_union})
      end
      let(:union_application_versions) do
        application_versions_3.merge({app_name => app_version_in_union})
      end

      describe "cached project metadata" do
        it "saved all apps and cookbooks for the current project" do
            expected_project_metadata = {
              project_name => {
                'applications' => new_application_metadata.keys,
                'cookbooks' => new_cookbook_versions.keys
              }
            }

            union_env_result =
              described_class.handle_union_pinnings(node)

            expect(union_env_result.default_attributes['delivery']['project_artifacts']).
              to eq(expected_project_metadata)
        end
      end

      it 'copies cookbook and application version pinnings from the acceptance' \
         ' environment to the union environment' do
        expected_union_cookbook_versions = union_cookbook_versions.
          merge(new_cookbook_versions)

        expected_union_application_versions = union_application_versions.
          merge(new_application_versions)

        union_env_result =
          described_class.handle_union_pinnings(node)

        expect(union_env_result.cookbook_versions).
          to eq(union_cookbook_versions)
        expect(union_env_result.override_attributes['applications']).
          to eq(expected_union_application_versions)
      end
    end
  end

end
