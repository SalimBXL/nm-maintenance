require 'test_helper'

class ApiTokensControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(name: 'Technicien', email_address: 'tech@example.com', password: 'secret', role: :technician)
    @other = User.create!(name: 'Autre', email_address: 'autre@example.com', password: 'secret', role: :technician)
  end

  test 'la gestion des jetons exige une connexion' do
    get api_tokens_url

    assert_redirected_to new_session_url
  end

  test "la liste n'affiche que mes jetons, sans jamais montrer le jeton complet" do
    mine = ApiToken.create!(user: @user, name: 'Poste labo')
    ApiToken.create!(user: @other, name: "Poste d'un collègue")
    sign_in_as @user

    get api_tokens_url

    assert_response :success
    assert_includes response.body, 'Poste labo'
    assert_not_includes response.body, 'Poste d&#39;un collègue'
    assert_includes response.body, "mt_…#{mine.hint}"
    assert_not_includes response.body, mine.plain_token
  end

  test 'la création affiche le jeton une seule fois' do
    sign_in_as @user

    assert_difference -> { ApiToken.count } => 1 do
      post api_tokens_url, params: { api_token: { name: 'Poste labo 2', duration: '90' } }
    end

    assert_response :success
    plain = response.body[/mt_[\w-]+/]
    assert plain.present?

    token = ApiToken.last
    assert_equal @user, token.user
    assert_equal token, ApiToken.authenticate(plain)
    assert_in_delta 90.days.from_now.to_i, token.expires_at.to_i, 120
    assert_not_includes token.attributes.values.map(&:to_s), plain

    get api_tokens_url
    assert_not_includes response.body, plain
  end

  test 'une durée inconnue donne un an' do
    sign_in_as @user

    post api_tokens_url, params: { api_token: { name: 'Poste', duration: '9999' } }

    assert_in_delta 365.days.from_now.to_i, ApiToken.last.expires_at.to_i, 120
  end

  test 'le nom est obligatoire' do
    sign_in_as @user

    assert_no_difference -> { ApiToken.count } do
      post api_tokens_url, params: { api_token: { name: '', duration: '365' } }
    end

    assert_response :unprocessable_entity
  end

  test 'je révoque mon jeton' do
    token = ApiToken.create!(user: @user, name: 'Poste labo')
    sign_in_as @user

    delete api_token_url(token)

    assert_redirected_to api_tokens_url
    assert token.reload.revoked_at.present?
    assert_nil ApiToken.authenticate(token.plain_token)
  end

  test "je ne peux pas révoquer le jeton d'un autre" do
    token = ApiToken.create!(user: @other, name: "Poste d'un collègue")
    sign_in_as @user

    delete api_token_url(token)

    assert_response :not_found
    assert_nil token.reload.revoked_at
  end
end
