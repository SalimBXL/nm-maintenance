require 'test_helper'

class IncidentFormTest < ActionDispatch::IntegrationTest
  setup do
    department = Department.create!(name: 'Caméras', code: 'CAM')
    location = Location.create!(department: department, name: 'Caméra 1', code: 'CAM1')
    category = EquipmentCategory.create!(name: 'SPECT', code_prefix: 'SPECT')
    manufacturer = Manufacturer.create!(name: 'GE', code: 'GE')
    model = EquipmentModel.create!(manufacturer: manufacturer, category: category, name: 'Modèle A')
    @equipment = Equipment.create!(equipment_model: model, location: location)

    @reporter = User.create!(name: 'Déclarant', email_address: 'decl@example.com', password: 'secret')
    @manager = User.create!(name: 'Responsable', email_address: 'resp@example.com', password: 'secret',
                            role: :technical_manager)
    DepartmentMembership.create!(user: @reporter, department: department)
  end

  test 'le formulaire de déclaration explique chaque niveau de gravité et chaque nature' do
    sign_in_as @reporter

    get new_incident_url

    assert_response :success
    assert_select "input[type=radio][name='incident[severity]']", 3
    assert_select "input[type=radio][name='incident[nature]']", 3
    assert_includes response.body, 'sans solution de repli'
    assert_includes response.body, 'Prise en charge visée'
    assert_includes response.body, 'radioprotection'
    assert_includes response.body, 'déclaration obligatoire'
  end

  test 'mineure et technique sont cochées par défaut' do
    sign_in_as @reporter

    get new_incident_url

    assert_select 'input#incident_severity_minor[checked]'
    assert_select 'input#incident_nature_technical[checked]'
  end

  test 'la gravité et la nature choisies sont enregistrées' do
    sign_in_as @reporter

    post incidents_url, params: {
      incident: {
        equipment_id: @equipment.id,
        description: 'Source égarée',
        severity: 'critical',
        nature: 'radiation_protection'
      }
    }

    incident = Incident.last
    assert incident.severity_critical?
    assert incident.nature_radiation_protection?
  end

  test 'la qualification propose les mêmes choix expliqués' do
    incident = Incident.create!(equipment: @equipment, reported_by: @reporter, description: 'Panne')
    sign_in_as @manager

    get incident_url(incident)

    assert_response :success
    assert_select "input[type=radio][name='incident[severity]']", 3
    assert_select "input[type=radio][name='incident[nature]']", 3
  end
end
