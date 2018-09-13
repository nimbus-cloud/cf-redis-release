require 'json'
require 'yaml'
require 'helpers/unit_spec_utilities'

include Helpers::Utilities

RSpec.describe 'smoke-tests config' do
  TEMPLATE_PATH = 'jobs/smoke-tests/templates/config.json.erb'
  JOB_NAME = 'smoke-tests'
  MINIMUM_MANIFEST = <<~MINIMUM_MANIFEST
  instance_groups:
  - name: smoke-tests
    jobs:
    - name: smoke-tests
      properties:
        cf:
          api_url: a-cf-url
          org_name: an-org-name
          space_name: a-space-name
          admin_username: a-username
          admin_password: a-password
          apps_domain: an-apps-domain
          system_domain: a-system-domain
          skip_ssl_validation: false
        redis:
          broker:
            service_instance_limit: 0
  MINIMUM_MANIFEST
  LINKS = {
    'redis_broker' => {
      'instances' => [
        {
          'address' => 'redis-broker-address'
        }
      ],
      'properties' => {}
    },
    'dedicated_node' => {
      'instances' => []
    }
  }

  context 'when only required properties are configured' do
    it 'templates the minimum config' do
      manifest = generate_manifest(MINIMUM_MANIFEST)
      actual_template = render_template(TEMPLATE_PATH, JOB_NAME, manifest, LINKS)
      expect(JSON.parse(actual_template)).to eq({
        'api' => 'a-cf-url',
        'org_name' => 'an-org-name',
        'space_name' => 'a-space-name',
        'apps_domain' => 'an-apps-domain',
        'system_domain' => 'a-system-domain',
        'admin_user' => 'a-username',
        'admin_password' => 'a-password',
        'service_name' => 'p-redis',
        'plan_names' => [],
        'retry' => {
          'max_attempts' => 10,
          'backoff' => 'constant',
          'baseline_interval_milliseconds' => 500
        },
        'skip_ssl_validation' => false,
        'create_permissive_security_group' => false,
        'security_groups' => [
          {
            'protocol' => 'tcp',
            'ports' => '32768-61000',
            'destination' => 'redis-broker-address'
          }
        ]
      })
    end
  end

  it 'allows the service name to be configured' do
    manifest = generate_manifest(MINIMUM_MANIFEST) do |m|
      m['instance_groups'].first['jobs'].first['properties']['redis']['broker']['service_name'] = 'a-service-name'
    end
    actual_template = render_template(TEMPLATE_PATH, JOB_NAME, manifest, LINKS)
    expect(JSON.parse(actual_template)['service_name']).to eq('a-service-name')
  end

  it 'allows retries to be configured' do
    manifest = generate_manifest(MINIMUM_MANIFEST) do |m|
      m['instance_groups'].first['jobs'].first['properties']['retry'] = {
        'max_attempts' => 5,
        'backoff' => 'linear',
        'baseline_interval_milliseconds' => 1000
      }
    end
    actual_template = render_template(TEMPLATE_PATH, JOB_NAME, manifest, LINKS)
    expect(JSON.parse(actual_template)['retry']).to eq({
      'max_attempts' => 5,
      'backoff' => 'linear',
      'baseline_interval_milliseconds' => 1000
    })
  end

  it 'configures testing of shared-vm plan' do
    manifest = generate_manifest(MINIMUM_MANIFEST) do |m|
      m['instance_groups'].first['jobs'].first['properties']['redis']['broker']['service_instance_limit'] = 1
    end
    actual_template = render_template(TEMPLATE_PATH, JOB_NAME, manifest, LINKS)
    expect(JSON.parse(actual_template)['plan_names']).to include('shared-vm')
  end

  context 'when redis.broker.dedicated_nodes property is not empty' do
    it 'configures testing of dedicated-vm plan using dedicated node addresses from the property' do
      manifest = generate_manifest(MINIMUM_MANIFEST) do |m|
        m['instance_groups'].first['jobs'].first['properties']['redis']['broker']['dedicated_nodes'] = [
          '10.0.9.15',
          '10.0.9.16'
        ]
      end

      actual_template = render_template(TEMPLATE_PATH, JOB_NAME, manifest, LINKS)

      actual_config = JSON.parse(actual_template)
      expect(actual_config['plan_names']).to include('dedicated-vm')
      expect(actual_config['security_groups']).to include(
        { 'protocol' => 'tcp', 'ports' => '6379', 'destination' => '10.0.9.15' },
        { 'protocol' => 'tcp', 'ports' => '6379', 'destination' => '10.0.9.16' }
      )
    end
  end

  context 'when redis.broker.dedicated_nodes property is empty' do
    it 'configures testing of dedicated-vm plan using dedicated node addresses from dedicated_node link' do
      manifest = generate_manifest(MINIMUM_MANIFEST)
      links_with_dedicated_nodes = LINKS.clone
      links_with_dedicated_nodes['dedicated_node']['instances'] = [
        {'address' => '10.0.10.5'},
        {'address' => '10.0.10.6'},
        {'address' => '10.0.10.7'}
      ]
      actual_template = render_template(TEMPLATE_PATH, JOB_NAME, manifest, links_with_dedicated_nodes)

      actual_config = JSON.parse(actual_template)
      expect(actual_config['plan_names']).to include('dedicated-vm')
      expect(actual_config['security_groups']).to include(
        { 'protocol' => 'tcp', 'ports' => '6379', 'destination' => '10.0.10.5' },
        { 'protocol' => 'tcp', 'ports' => '6379', 'destination' => '10.0.10.6' },
        { 'protocol' => 'tcp', 'ports' => '6379', 'destination' => '10.0.10.7' },
      )
    end
  end

  end
