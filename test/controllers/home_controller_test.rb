require 'test_helper'

class HomeControllerTest < ActionDispatch::IntegrationTest
  test "la page d'accueil est accessible une fois connecté" do
    sign_in_as users(:one)
    get root_url
    assert_response :success
  end

  test "la page d'accueil redirige vers la connexion sans session" do
    get root_url
    assert_redirected_to new_session_url
  end
end
