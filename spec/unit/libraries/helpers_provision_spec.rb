require 'spec_helper'

describe DeliveryTruck::Helpers::Provision do
  let(:project_name) { 'delivery' }

  let(:node) { instance_double('Chef::Node') }

  let(:node_attributes) do
    {
      'delivery' => {
        'change' => {
          'project' => project_name
        }
      }
    }
  end

  before(:each) do
    allow(described_class).
      to receive(:node).
      and_return(node)
    allow(node).
      to receive(:[]).
      with('delivery').
      and_return(node_attributes['delivery'])
    allow(node).
      to receive(:default).
      and_return(node_attributes)
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
          described_class.project_cookbook_version_pins_from_env(env)
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
          described_class.project_cookbook_version_pins_from_env(env)
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
          described_class.project_application_version_pins_from_env(env)
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
            described_class.project_application_version_pins_from_env(env)
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
          described_class.project_application_version_pins_from_env(env)
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
          described_class.handle_acceptance_pinnings(acceptance_env_name)
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
        node['delivery']['project_cookbooks'] = []
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
          described_class.handle_acceptance_pinnings(acceptance_env_name)
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

      before(:each) do
        node['delivery']['project_cookbooks'] = [project_cookbook_name]
        node['delivery']['project_apps'] = [project_app_name]
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
          described_class.handle_acceptance_pinnings(acceptance_env_name)
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

    context 'when the project is a cookbook' do
      let(:acceptance_application_versions) { {} }

      let(:acceptance_cookbook_versions) do
        {
          project_name => project_version_in_acceptance
        }
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

      it 'copies cookbook version pinnings from the acceptance environment' \
         ' to the union environment' do
        expected_union_cookbook_versions =
          union_cookbook_versions.dup # copy, don't mutate incoming test state
        expected_union_cookbook_versions[project_name] =
          project_version_in_acceptance

        union_env_result =
          described_class.handle_union_pinnings(acceptance_env_name)

        expect(union_env_result.cookbook_versions).
          to eq(expected_union_cookbook_versions)
        expect(union_env_result.override_attributes['applications']).
          to eq(union_application_versions)
      end
    end

    context 'when the project is an application' do
      let(:acceptance_application_versions) do
        {
          project_name => project_version_in_acceptance
        }
      end

      let(:acceptance_cookbook_versions) { {} }

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
        node['delivery']['project_cookbooks'] = []
      end

      it 'copies application version pinnings from the acceptance environment' \
         ' to the union environment' do
        expected_union_application_versions = union_application_versions.dup
        expected_union_application_versions[project_name] =
          project_version_in_acceptance

        union_env_result =
          described_class.handle_union_pinnings(acceptance_env_name)

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
        node['delivery']['project_cookbooks'] = project_cookbook_names
        node['delivery']['project_apps'] = [project_app_name]
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
          described_class.handle_union_pinnings(acceptance_env_name)

        expect(union_env_result.cookbook_versions).
          to eq(union_cookbook_versions)
        expect(union_env_result.override_attributes['applications']).
          to eq(expected_union_application_versions)
      end
    end
  end

  describe '.handle_other_pinnings' do
    let(:previous_stage_env_name) { 'union' }

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

    let(:current_stage_env_name) { 'rehearsal' }

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
      expected_cookbook_versions['no_longer_supported_cookbook'] = '= 2.3.0'

      expected_applications = previous_stage_applications.dup

      expected_default_attributes = previous_stage_default_attributes.dup

      current_stage_env_result =
        described_class.handle_other_pinnings(current_stage_env_name)

      expect(current_stage_env_result.cookbook_versions).
        to eq(expected_cookbook_versions)
      expect(current_stage_env_result.default_attributes).
        to eq(expected_default_attributes)
      expect(current_stage_env_result.override_attributes['applications']).
        to eq(expected_applications)
    end
  end

end
