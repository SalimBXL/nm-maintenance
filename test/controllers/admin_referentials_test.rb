require 'test_helper'

class AdminReferentialsTest < ActionDispatch::IntegrationTest
  setup do
    @department = Department.create!(name: 'Caméras', code: 'CAM')
    @camera1 = Location.create!(department: @department, name: 'Caméra 1', code: 'CAM1')
    @spect = EquipmentCategory.create!(name: 'SPECT', code_prefix: 'SPECT')
    @ge = Manufacturer.create!(name: 'GE', code: 'GE')
    @model = EquipmentModel.create!(manufacturer: @ge, category: @spect, name: 'Modèle A')

    @admin = User.create!(name: 'Admin', email_address: 'admin@example.com', password: 'secret', role: :admin)
    @manager = User.create!(name: 'Responsable', email_address: 'resp@example.com', password: 'secret',
                            role: :technical_manager)
    @technician = User.create!(name: 'Technicien', email_address: 'tech@example.com', password: 'secret',
                               role: :technician)
  end

  # --- Accès

  test "l'administration exige une connexion" do
    get admin_departments_url

    assert_redirected_to new_session_url
  end

  test "technicien et déclarant n'accèdent pas à l'administration" do
    sign_in_as @technician

    get admin_locations_url

    assert_redirected_to root_path
  end

  test 'le responsable technique consulte les référentiels' do
    sign_in_as @manager

    [admin_departments_url, admin_locations_url, admin_equipment_categories_url,
     admin_manufacturers_url, admin_equipment_models_url].each do |url|
      get url
      assert_response :success, url
    end

    get admin_locations_url
    assert_includes response.body, 'Caméra 1'
  end

  # --- Départements : écriture réservée aux administrateurs

  test 'le responsable technique ne crée pas de département' do
    sign_in_as @manager

    assert_no_difference -> { Department.count } do
      post admin_departments_url, params: { department: { name: 'Laboratoires', code: 'LABO' } }
    end
    assert_redirected_to root_path
  end

  test "l'administrateur crée un département avec son responsable" do
    sign_in_as @admin

    assert_difference -> { Department.count } => 1 do
      post admin_departments_url,
           params: { department: { name: 'Laboratoires', code: 'LABO', manager_id: @manager.id } }
    end

    assert_redirected_to admin_departments_url
    assert_equal @manager, Department.find_by!(code: 'LABO').manager
  end

  # --- Locaux

  test 'le responsable technique crée un local' do
    sign_in_as @manager

    assert_difference -> { Location.count } => 1 do
      post admin_locations_url, params: { location: { department_id: @department.id, name: 'Caméra 2', code: 'CAM2' } }
    end

    assert_redirected_to admin_locations_url
  end

  test 'un code de local en double dans le département est refusé' do
    sign_in_as @manager

    assert_no_difference -> { Location.count } do
      post admin_locations_url, params: { location: { department_id: @department.id, name: 'Autre', code: 'CAM1' } }
    end

    assert_response :unprocessable_entity
  end

  test "le département d'un local ne se modifie pas" do
    other = Department.create!(name: 'Laboratoires', code: 'LABO')
    sign_in_as @manager

    patch admin_location_url(@camera1), params: { location: { department_id: other.id, name: 'Caméra 1 bis' } }

    assert_equal @department, @camera1.reload.department
    assert_equal 'Caméra 1 bis', @camera1.name
  end

  # --- Catégories et fabricants

  test 'le préfixe de type est mis en majuscules' do
    sign_in_as @manager

    post admin_equipment_categories_url, params: { equipment_category: { name: 'Activimètre', code_prefix: 'act' } }

    assert_redirected_to admin_equipment_categories_url
    assert_equal 'ACT', EquipmentCategory.find_by!(name: 'Activimètre').code_prefix
  end

  test 'un préfixe avec tiret est refusé' do
    sign_in_as @manager

    assert_no_difference -> { EquipmentCategory.count } do
      post admin_equipment_categories_url, params: { equipment_category: { name: 'PET-CT', code_prefix: 'PET-CT' } }
    end

    assert_response :unprocessable_entity
  end

  test "le préfixe d'une catégorie ne se modifie plus après sa création" do
    sign_in_as @manager

    patch admin_equipment_category_url(@spect),
          params: { equipment_category: { name: 'SPECT classique', code_prefix: 'ZZZ' } }

    @spect.reload
    assert_equal 'SPECT', @spect.code_prefix
    assert_equal 'SPECT classique', @spect.name
  end

  test "création d'un fabricant avec son code court" do
    sign_in_as @manager

    post admin_manufacturers_url, params: { manufacturer: { name: 'Veenstra Instruments (gamme VIK)', code: 'vik' } }

    assert_equal 'VIK', Manufacturer.find_by!(name: 'Veenstra Instruments (gamme VIK)').code
  end

  # --- Modèles

  test "création d'un modèle d'équipement" do
    petct = EquipmentCategory.create!(name: 'PET-CT', code_prefix: 'PETCT')
    sign_in_as @manager

    assert_difference -> { EquipmentModel.count } => 1 do
      post admin_equipment_models_url, params: {
        equipment_model: { manufacturer_id: @ge.id, category_id: petct.id, name: 'Modèle C' }
      }
    end

    assert_redirected_to admin_equipment_models_url
  end

  # --- Archivage

  test 'un département avec des locaux actifs ne peut pas être archivé' do
    sign_in_as @admin

    post archive_admin_department_url(@department)
    assert_redirected_to admin_departments_url
    assert_not @department.reload.archived?

    @camera1.archive!
    post archive_admin_department_url(@department)
    assert @department.reload.archived?
  end

  test 'un local avec des équipements actifs ne peut pas être archivé' do
    Equipment.create!(equipment_model: @model, location: @camera1)
    sign_in_as @manager

    post archive_admin_location_url(@camera1)

    assert_not @camera1.reload.archived?
  end

  test 'un enregistrement archivé peut être réactivé' do
    @camera1.archive!
    sign_in_as @manager

    post unarchive_admin_location_url(@camera1)

    assert_not @camera1.reload.archived?
  end
end
