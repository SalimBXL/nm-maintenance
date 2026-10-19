require 'test_helper'

class DashboardControllerTest < ActionDispatch::IntegrationTest
  setup do
    department = Department.create!(name: 'Caméras', code: 'CAM')
    location = Location.create!(department: department, name: 'Caméra 1', code: 'CAM1')
    category = EquipmentCategory.create!(name: 'SPECT', code_prefix: 'SPECT')
    manufacturer = Manufacturer.create!(name: 'GE', code: 'GE')
    model = EquipmentModel.create!(manufacturer: manufacturer, category: category, name: 'Modèle A')
    @equipment = Equipment.create!(equipment_model: model, location: location)
    @broken = Equipment.create!(equipment_model: model, location: location, status: :out_of_order)

    @reporter = User.create!(name: 'Déclarant', email_address: 'decl@example.com', password: 'secret')
    @manager = User.create!(name: 'Responsable', email_address: 'resp@example.com', password: 'secret', role: :technical_manager)
  end

  test 'le tableau de bord exige une connexion' do
    get dashboard_url

    assert_redirected_to new_session_url
  end

  test "la page d'accueil est le tableau de bord" do
    sign_in_as @reporter

    get root_url

    assert_response :success
    assert_select 'h1', 'Tableau de bord'
  end

  test 'les chiffres du parc sont affichés avec un lien vers la liste filtrée' do
    sign_in_as @reporter

    get dashboard_url

    assert_select "[data-kpi='equipment-in_service'] .kpi-value", '1'
    assert_select "[data-kpi='equipment-out_of_order'] .kpi-value", '1'
    assert_select "a[data-kpi='equipment-out_of_order'][href=?]", equipments_path(status: 'out_of_order')
  end

  test 'les incidents ouverts sont comptés par gravité' do
    Incident.create!(equipment: @equipment, reported_by: @reporter, description: 'Détecteur HS', severity: :critical)
    Incident.create!(equipment: @equipment, reported_by: @reporter, description: 'Bruit anormal', severity: :major)
    sign_in_as @reporter

    get dashboard_url

    assert_select "[data-kpi='incidents-critical'] .kpi-value", '1'
    assert_select "[data-kpi='incidents-major'] .kpi-value", '1'
    assert_select "[data-kpi='incidents-minor'] .kpi-value", '0'
    assert_select "[data-section='urgent']", text: /Détecteur HS/
  end

  test 'le déclarant voit ses incidents dans « À traiter »' do
    Incident.create!(equipment: @equipment, reported_by: @reporter, description: 'Panne caméra', severity: :minor)
    sign_in_as @reporter

    get dashboard_url

    assert_select "[data-section='tasks']", text: /Mes incidents ouverts/
    assert_select "[data-section='tasks']", text: /Panne caméra/
  end

  test 'le responsable technique voit les incidents à qualifier' do
    Incident.create!(equipment: @equipment, reported_by: @reporter, description: 'Panne caméra', severity: :minor)
    sign_in_as @manager

    get dashboard_url

    assert_select "[data-section='tasks']", text: /Incidents à qualifier/
    assert_select "[data-kpi='incidents-to_qualify'] .kpi-value", '1'
  end

  test "rien à traiter est indiqué quand il n'y a aucune tâche" do
    sign_in_as @reporter

    get dashboard_url

    assert_select "[data-section='tasks']", text: /Rien à traiter/
  end

  test 'la vue par département est affichée' do
    sign_in_as @reporter

    get dashboard_url

    assert_select "[data-section='departments']", text: /Caméras/
  end
end
