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
        'create_permissive_security_group' => true,
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

end
