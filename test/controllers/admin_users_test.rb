require "test_helper"

class AdminUsersTest < ActionDispatch::IntegrationTest
  setup do
    @cameras = Department.create!(name: "Caméras", code: "CAM")
    @labs = Department.create!(name: "Laboratoires", code: "LABO")

    @admin = User.create!(name: "Admin", email_address: "admin@example.com", password: "secret", role: :admin)
    @manager = User.create!(name: "Responsable", email_address: "resp@example.com", password: "secret", role: :technical_manager)
    @technician = User.create!(name: "Technicien", email_address: "tech@example.com", password: "secret", role: :technician)
  end

  # --- Accès

  test "la gestion des utilisateurs est réservée aux administrateurs" do
    sign_in_as @manager

    get admin_users_url
    assert_redirected_to root_path

    assert_no_difference -> { User.count } do
      post admin_users_url, params: { user: { name: "X", email_address: "x@example.com", password: "secret", password_confirmation: "secret" } }
    end
  end

  test "l'administrateur consulte la liste" do
    sign_in_as @admin

    get admin_users_url

    assert_response :success
    assert_includes response.body, "Technicien"
  end

  # --- Création

  test "création d'un compte avec rôle, validité et départements" do
    sign_in_as @admin

    assert_difference -> { User.count } => 1 do
      post admin_users_url, params: {
        user: {
          name: "Nouvelle", email_address: "NOUVELLE@example.com", role: "technician",
          valid_until: "2030-12-31", password: "motdepasse", password_confirmation: "motdepasse",
          department_ids: ["", @cameras.id.to_s]
        }
      }
    end

    assert_redirected_to admin_users_url
    user = User.find_by!(email_address: "nouvelle@example.com")
    assert user.technician?
    assert_equal Date.new(2030, 12, 31), user.valid_until
    assert_equal [@cameras], user.departments.to_a
    assert_equal user, User.authenticate_by(email_address: "nouvelle@example.com", password: "motdepasse")
  end

  test "une création invalide réaffiche le formulaire" do
    sign_in_as @admin

    assert_no_difference -> { User.count } do
      post admin_users_url, params: { user: { name: "", email_address: "x@example.com", password: "a", password_confirmation: "b" } }
    end

    assert_response :unprocessable_entity
  end

  # --- Modification

  test "sans nouveau mot de passe, le mot de passe est conservé" do
    sign_in_as @admin
    digest = @technician.password_digest

    patch admin_user_url(@technician), params: { user: { name: "Technicien Renommé", password: "", password_confirmation: "" } }

    assert_redirected_to admin_users_url
    @technician.reload
    assert_equal "Technicien Renommé", @technician.name
    assert_equal digest, @technician.password_digest
  end

  test "un nouveau mot de passe remplace l'ancien" do
    sign_in_as @admin

    patch admin_user_url(@technician), params: { user: { password: "nouveau-mdp", password_confirmation: "nouveau-mdp" } }

    assert_equal @technician, User.authenticate_by(email_address: "tech@example.com", password: "nouveau-mdp")
    assert_nil User.authenticate_by(email_address: "tech@example.com", password: "secret")
  end

  test "les appartenances aux départements sont synchronisées et les retraits tracés" do
    DepartmentMembership.create!(user: @technician, department: @cameras)
    sign_in_as @admin

    patch admin_user_url(@technician), params: { user: { department_ids: ["", @labs.id.to_s] } }

    assert_equal [@labs], @technician.reload.departments.to_a
    assert PaperTrail::Version.where(item_type: "DepartmentMembership", event: "destroy").exists?
  end

  # --- Désactivation

  test "la désactivation fixe la date de fin à la veille et ferme les sessions" do
    @technician.sessions.create!
    sign_in_as @admin

    post deactivate_admin_user_url(@technician)

    @technician.reload
    assert_equal Time.zone.yesterday, @technician.valid_until
    assert_not @technician.active?
    assert_equal 0, @technician.sessions.count
    assert_nil User.authenticate_by(email_address: "tech@example.com", password: "secret")
  end

  test "la réactivation supprime la date de fin" do
    @technician.update!(valid_until: Time.zone.yesterday)
    sign_in_as @admin

    post reactivate_admin_user_url(@technician)

    assert_nil @technician.reload.valid_until
    assert @technician.active?
  end

  # --- Dernier administrateur

  test "le dernier administrateur actif ne peut pas se désactiver" do
    sign_in_as @admin

    post deactivate_admin_user_url(@admin)

    assert @admin.reload.active?
  end

  test "le dernier administrateur actif ne peut pas perdre son rôle" do
    sign_in_as @admin

    patch admin_user_url(@admin), params: { user: { role: "technician" } }

    assert_response :unprocessable_entity
    assert @admin.reload.admin?
  end

  test "un administrateur peut être rétrogradé s'il en reste un autre" do
    other = User.create!(name: "Autre admin", email_address: "autre@example.com", password: "secret", role: :admin)
    sign_in_as @admin

    patch admin_user_url(other), params: { user: { role: "technician" } }

    assert_redirected_to admin_users_url
    assert other.reload.technician?
  end
end
