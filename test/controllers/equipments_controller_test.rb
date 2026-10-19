require "test_helper"

class EquipmentsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @department = Department.create!(name: "Caméras", code: "CAM")
    @camera1 = Location.create!(department: @department, name: "Caméra 1", code: "CAM1")
    @camera2 = Location.create!(department: @department, name: "Caméra 2", code: "CAM2")
    @spect = EquipmentCategory.create!(name: "SPECT", code_prefix: "SPECT")
    @petct = EquipmentCategory.create!(name: "PET-CT", code_prefix: "PETCT")
    @ge = Manufacturer.create!(name: "GE", code: "GE")
    @spect_model = EquipmentModel.create!(manufacturer: @ge, category: @spect, name: "Modèle A")
    @petct_model = EquipmentModel.create!(manufacturer: @ge, category: @petct, name: "Modèle C")
    @equipment = Equipment.create!(equipment_model: @spect_model, location: @camera1, serial_number: "SN-100")

    @manager = User.create!(name: "Responsable", email_address: "resp@example.com", password: "secret", role: :technical_manager)
    @reporter = users(:one) # rôle par défaut : déclarant
  end

  # --- Consultation

  test "la liste exige une connexion" do
    get equipments_url

    assert_redirected_to new_session_url
  end

  test "un déclarant consulte la liste" do
    sign_in_as @reporter

    get equipments_url

    assert_response :success
    assert_includes response.body, @equipment.code
  end

  test "filtre par statut" do
    other = Equipment.create!(equipment_model: @petct_model, location: @camera1, status: :out_of_order)
    sign_in_as @reporter

    get equipments_url(status: "out_of_order")

    assert_includes response.body, other.code
    assert_not_includes response.body, @equipment.code
  end

  test "filtre par catégorie" do
    other = Equipment.create!(equipment_model: @petct_model, location: @camera1)
    sign_in_as @reporter

    get equipments_url(category_id: @petct.id)

    assert_includes response.body, other.code
    assert_not_includes response.body, @equipment.code
  end

  test "recherche par numéro de série" do
    other = Equipment.create!(equipment_model: @petct_model, location: @camera1)
    sign_in_as @reporter

    get equipments_url(q: "SN-100")

    assert_includes response.body, @equipment.code
    assert_not_includes response.body, other.code
  end

  test "les équipements archivés sont masqués par défaut" do
    @equipment.archive!
    sign_in_as @reporter

    get equipments_url
    assert_not_includes response.body, @equipment.code

    get equipments_url(archived: "1")
    assert_includes response.body, @equipment.code
  end

  test "la fiche affiche l'équipement" do
    sign_in_as @reporter

    get equipment_url(@equipment)

    assert_response :success
    assert_includes response.body, @equipment.code
    assert_includes response.body, "Historique des déplacements"
  end

  # --- Droits

  test "un déclarant ne peut ni créer ni modifier" do
    sign_in_as @reporter

    get new_equipment_url
    assert_redirected_to root_path

    assert_no_difference -> { Equipment.count } do
      post equipments_url, params: { equipment: { equipment_model_id: @petct_model.id, location_id: @camera1.id } }
    end
    assert_redirected_to root_path

    patch equipment_url(@equipment), params: { equipment: { serial_number: "SN-999" } }
    assert_equal "SN-100", @equipment.reload.serial_number
  end

  test "un déclarant ne peut pas archiver" do
    sign_in_as @reporter

    post archive_equipment_url(@equipment)

    assert_not @equipment.reload.archived?
  end

  # --- Gestion du parc

  test "un responsable technique crée un équipement avec un code généré" do
    sign_in_as @manager

    assert_difference -> { Equipment.count } => 1 do
      post equipments_url, params: {
        equipment: { equipment_model_id: @petct_model.id, location_id: @camera1.id, serial_number: "SN-200", criticality: "high" }
      }
    end

    created = Equipment.find_by!(serial_number: "SN-200")
    assert_redirected_to equipment_url(created)
    assert_equal "PETCT-GE-01", created.code
    assert_equal "high", created.criticality
  end

  test "une création invalide réaffiche le formulaire" do
    sign_in_as @manager

    assert_no_difference -> { Equipment.count } do
      post equipments_url, params: { equipment: { location_id: @camera1.id } }
    end

    assert_response :unprocessable_entity
  end

  test "la modification change le local et enregistre le déplacement, mais jamais le modèle" do
    sign_in_as @manager

    patch equipment_url(@equipment), params: {
      equipment: { location_id: @camera2.id, equipment_model_id: @petct_model.id }
    }

    assert_redirected_to equipment_url(@equipment)
    @equipment.reload
    assert_equal @camera2, @equipment.location
    assert_equal @spect_model, @equipment.equipment_model

    move = @equipment.equipment_moves.last
    assert_equal @camera1, move.from_location
    assert_equal @camera2, move.to_location
    assert_equal @manager, move.user
  end

  test "la mise hors service exige une date" do
    sign_in_as @manager

    patch equipment_url(@equipment), params: { equipment: { status: "decommissioned" } }
    assert_response :unprocessable_entity

    patch equipment_url(@equipment), params: { equipment: { status: "decommissioned", decommissioned_on: "2026-10-01" } }
    assert_redirected_to equipment_url(@equipment)
    assert @equipment.reload.decommissioned?
  end

  test "un responsable technique archive puis réactive un équipement" do
    sign_in_as @manager

    post archive_equipment_url(@equipment)
    assert @equipment.reload.archived?

    post unarchive_equipment_url(@equipment)
    assert_not @equipment.reload.archived?
  end
end
