require "test_helper"

class UserValidityTest < ActiveSupport::TestCase
  def user_with(valid_until)
    User.new(name: "Test", email_address: "test@example.com", password: "secret", valid_until: valid_until)
  end

  test "sans date de fin, l'utilisateur est actif" do
    assert user_with(nil).active?
  end

  test "le compte reste actif le jour de la date de fin" do
    assert user_with(Time.zone.today).active?
  end

  test "une date de fin future garde le compte actif" do
    assert user_with(Time.zone.today + 1).active?
  end

  test "une date de fin passée rend le compte non actif" do
    assert_not user_with(Time.zone.today - 1).active?
  end

  test "les scopes active et inactive suivent la même règle" do
    expired = User.create!(name: "Ancien", email_address: "ancien@example.com", password: "secret", valid_until: Time.zone.today - 1)
    current = User.create!(name: "Actuel", email_address: "actuel@example.com", password: "secret")

    assert_includes User.inactive, expired
    assert_not_includes User.active, expired
    assert_includes User.active, current
  end

  test "un utilisateur non actif ne peut pas s'authentifier" do
    User.create!(name: "Ancien", email_address: "ancien@example.com", password: "secret", valid_until: Time.zone.today - 1)

    assert_nil User.authenticate_by(email_address: "ancien@example.com", password: "secret")
  end

  test "un utilisateur actif peut s'authentifier" do
    user = User.create!(name: "Actuel", email_address: "actuel@example.com", password: "secret")

    assert_equal user, User.authenticate_by(email_address: "actuel@example.com", password: "secret")
  end
end
