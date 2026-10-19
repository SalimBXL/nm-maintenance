require 'test_helper'

class ApiTokenTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(name: 'Technicien', email_address: 'tech@example.com', password: 'secret', role: :technician)
  end

  def create_token(**attributes)
    ApiToken.create!({ user: @user, name: 'Poste labo' }.merge(attributes))
  end

  test "le jeton en clair n'est disponible qu'à la création et seule son empreinte est stockée" do
    token = create_token

    assert token.plain_token.start_with?('mt_')
    assert_equal ApiToken.digest(token.plain_token), token.token_digest
    assert_not_includes token.attributes.values.map(&:to_s), token.plain_token
    assert_nil ApiToken.find(token.id).plain_token
  end

  test "l'indice reprend les derniers caractères du jeton" do
    token = create_token

    assert_equal token.plain_token.last(4), token.hint
  end

  test "la validité par défaut est d'un an" do
    token = create_token

    assert_in_delta 365.days.from_now.to_i, token.expires_at.to_i, 60
  end

  test 'le nom est obligatoire' do
    assert_not ApiToken.new(user: @user, name: '').valid?
  end

  test "deux jetons n'ont jamais la même empreinte" do
    assert_not_equal create_token.token_digest, create_token.token_digest
  end

  test 'authenticate retrouve le jeton valide' do
    token = create_token

    assert_equal token, ApiToken.authenticate(token.plain_token)
  end

  test 'authenticate refuse un jeton inconnu ou vide' do
    assert_nil ApiToken.authenticate('mt_inconnu')
    assert_nil ApiToken.authenticate('')
    assert_nil ApiToken.authenticate(nil)
  end

  test 'authenticate refuse un jeton expiré' do
    token = create_token(expires_at: 1.minute.ago)

    assert_nil ApiToken.authenticate(token.plain_token)
    assert_not token.usable?
  end

  test 'authenticate refuse un jeton révoqué' do
    token = create_token
    token.revoke!

    assert_nil ApiToken.authenticate(token.plain_token)
    assert_not token.usable?
  end

  test "authenticate refuse le jeton d'un utilisateur non actif" do
    token = create_token
    @user.update!(valid_until: Time.zone.today - 1)

    assert_nil ApiToken.authenticate(token.plain_token)
  end

  test 'la portée usable exclut les jetons expirés et révoqués' do
    valid = create_token(name: 'Valide')
    create_token(name: 'Expiré', expires_at: 1.day.ago)
    create_token(name: 'Révoqué').revoke!

    assert_equal [valid], ApiToken.usable.to_a
  end

  test "la dernière utilisation n'est mise à jour qu'une fois toutes les cinq minutes" do
    token = create_token

    token.touch_last_used!
    first = token.reload.last_used_at
    assert first.present?

    token.touch_last_used!
    assert_equal first, token.reload.last_used_at

    token.update_columns(last_used_at: 10.minutes.ago)
    token.touch_last_used!
    assert_operator token.reload.last_used_at, :>, 1.minute.ago
  end
end
