require_relative 'api_test_case'

class ApiAuthenticationTest < ApiTestCase
  test "sans jeton, l'API répond 401 avec le format d'erreur unique" do
    get api_v1_me_url

    assert_response :unauthorized
    assert_equal 'unauthorized', json['error']['code']
    assert json['error']['message'].present?
    assert_includes response.headers['WWW-Authenticate'], 'Bearer'
  end

  test 'un jeton inconnu est refusé' do
    get api_v1_me_url, headers: { 'Authorization' => 'Bearer mt_inconnu' }

    assert_response :unauthorized
  end

  test "un jeton valide donne accès à l'utilisateur courant" do
    get api_v1_me_url, headers: auth(@reporter)

    assert_response :success
    data = json['data']
    assert_equal @reporter.id, data['id']
    assert_equal 'reporter', data['role']
    assert_equal @reporter.email_address, data['email']
    assert_equal([@cameras.id], data['departments'].pluck('id'))
  end

  test 'un jeton expiré est refusé' do
    token = ApiToken.create!(user: @reporter, name: 'Ancien', expires_at: 1.minute.ago)

    get api_v1_me_url, headers: { 'Authorization' => "Bearer #{token.plain_token}" }

    assert_response :unauthorized
  end

  test 'un jeton révoqué est refusé' do
    token = ApiToken.create!(user: @reporter, name: 'Révoqué')
    token.revoke!

    get api_v1_me_url, headers: { 'Authorization' => "Bearer #{token.plain_token}" }

    assert_response :unauthorized
  end

  test "le jeton d'un utilisateur non actif est refusé" do
    headers = auth(@reporter)
    @reporter.update!(valid_until: Time.zone.today - 1)

    get api_v1_me_url, headers: headers

    assert_response :unauthorized
  end

  test "l'appel met à jour la dernière utilisation du jeton" do
    token = ApiToken.create!(user: @reporter, name: 'Suivi')

    get api_v1_me_url, headers: { 'Authorization' => "Bearer #{token.plain_token}" }

    assert token.reload.last_used_at.present?
  end

  test "une adresse inconnue répond en JSON avec le format d'erreur" do
    get api_v1_equipment_url(0), headers: auth(@reporter)

    assert_response :not_found
    assert_equal 'not_found', json['error']['code']
  end
end
