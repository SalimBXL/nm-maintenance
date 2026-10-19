require_relative 'api_test_case'

class ApiOpenapiTest < ApiTestCase
  def spec
    YAML.safe_load_file(Rails.root.join('openapi/v1.yaml'))
  end

  test 'la spécification est servie sans jeton' do
    get api_v1_openapi_url

    assert_response :success
    assert_includes response.content_type, 'yaml'
    assert_equal '3.0.3', YAML.safe_load(response.body)['openapi']
  end

  test "la spécification décrit exactement les routes de l'API v1" do
    documented = spec['paths'].flat_map do |path, operations|
      operations.keys.select { |key| %w[get post put patch delete].include?(key) }
                .map { |verb| [verb.upcase, "/api/v1#{path}".gsub(/\{(\w+)\}/, ':\1')] }
    end

    actual = Rails.application.routes.routes
                  .select { |route| route.path.spec.to_s.start_with?('/api/v1') }
                  .map { |route| [route.verb, route.path.spec.to_s.sub('(.:format)', '')] }

    assert_empty documented - actual, 'Documentés dans la spécification mais sans route'
    assert_empty actual - documented, 'Routes absentes de la spécification'
  end

  test 'chaque opération documentée a un résumé et au moins une réponse' do
    spec['paths'].each do |path, operations|
      operations.each do |verb, operation|
        next unless %w[get post put patch delete].include?(verb)

        assert operation['summary'].present?, "#{verb} #{path} : résumé manquant"
        assert operation['responses'].present?, "#{verb} #{path} : réponses manquantes"
      end
    end
  end

  test 'les références internes de la spécification existent' do
    references = spec.to_s.scan(%r{#/components/(\w+)/(\w+)}).uniq

    references.each do |section, name|
      assert spec['components'][section].key?(name), "Référence inconnue : #/components/#{section}/#{name}"
    end
  end
end
