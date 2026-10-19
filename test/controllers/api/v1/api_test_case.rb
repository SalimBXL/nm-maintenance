require 'test_helper'

# Base des tests de l'API : un petit parc, quatre utilisateurs (un par rôle)
# et des aides pour s'authentifier par jeton.
class ApiTestCase < ActionDispatch::IntegrationTest
  setup do
    @cameras = Department.create!(name: 'Caméras', code: 'CAM')
    @labs = Department.create!(name: 'Laboratoires', code: 'LABO')
    @camera1 = Location.create!(department: @cameras, name: 'Caméra 1', code: 'CAM1')
    @lab_room = Location.create!(department: @labs, name: 'Labo chaud', code: 'LC')
    @category = EquipmentCategory.create!(name: 'SPECT', code_prefix: 'SPECT')
    manufacturer = Manufacturer.create!(name: 'GE', code: 'GE')
    @model = EquipmentModel.create!(manufacturer: manufacturer, category: @category, name: 'Modèle A')
    @equipment = Equipment.create!(equipment_model: @model, location: @camera1, serial_number: 'SN-100')
    @lab_equipment = Equipment.create!(equipment_model: @model, location: @lab_room)

    @manager = make_user('Responsable', :technical_manager)
    @technician = make_user('Technicien', :technician)
    @reporter = make_user('Déclarant', :reporter)
    DepartmentMembership.create!(user: @reporter, department: @cameras)
  end

  def make_user(name, role)
    User.create!(name: name, email_address: "#{name.parameterize}@example.com", password: 'secret', role: role)
  end

  # En-têtes d'authentification pour un utilisateur (un jeton neuf est créé).
  def auth(user)
    token = ApiToken.create!(user: user, name: 'Test')
    { 'Authorization' => "Bearer #{token.plain_token}" }
  end

  def json
    JSON.parse(response.body)
  end
end
