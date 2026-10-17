require 'test_helper'

class IncidentsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @cameras = Department.create!(name: 'Caméras', code: 'CAM')
    @labs = Department.create!(name: 'Laboratoires', code: 'LABO')
    @camera1 = Location.create!(department: @cameras, name: 'Caméra 1', code: 'CAM1')
    @lab_room = Location.create!(department: @labs, name: 'Labo chaud', code: 'LC')
    category = EquipmentCategory.create!(name: 'SPECT', code_prefix: 'SPECT')
    manufacturer = Manufacturer.create!(name: 'GE', code: 'GE')
    model = EquipmentModel.create!(manufacturer: manufacturer, category: category, name: 'Modèle A')
    @equipment = Equipment.create!(equipment_model: model, location: @camera1)
    @lab_equipment = Equipment.create!(equipment_model: model, location: @lab_room)

    @manager = make_user('Responsable', :technical_manager)
    @technician = make_user('Technicien', :technician)
    @other_technician = make_user('Autre technicien', :technician)
    @reporter = make_user('Déclarant', :reporter)
    DepartmentMembership.create!(user: @reporter, department: @cameras)
  end

  def make_user(name, role)
    User.create!(name: name, email_address: "#{name.parameterize}@example.com", password: 'secret', role: role)
  end

  def declare(description: 'Panne alpha', equipment: @equipment, **attributes)
    Incident.create!({ equipment: equipment, reported_by: @reporter, description: description,
                       severity: :major }.merge(attributes))
  end

  # --- Liste

  test 'la liste exige une connexion' do
    get incidents_url

    assert_redirected_to new_session_url
  end

  test 'la liste affiche par défaut les incidents ouverts seulement' do
    declare(description: 'Panne alpha')
    closed = declare(description: 'Panne beta')
    closed.update_columns(status: 'closed')
    sign_in_as @reporter

    get incidents_url
    assert_includes response.body, 'Panne alpha'
    assert_not_includes response.body, 'Panne beta'

    get incidents_url(status: 'all')
    assert_includes response.body, 'Panne beta'
  end

  test 'filtre par gravité et par département' do
    declare(description: 'Panne alpha', severity: :critical)
    declare(description: 'Panne gamma', severity: :minor, equipment: @lab_equipment)
    sign_in_as @reporter

    get incidents_url(severity: 'critical')
    assert_includes response.body, 'Panne alpha'
    assert_not_includes response.body, 'Panne gamma'

    get incidents_url(department_id: @labs.id)
    assert_includes response.body, 'Panne gamma'
    assert_not_includes response.body, 'Panne alpha'
  end

  # --- Déclaration

  test 'un déclarant déclare un incident dans son département' do
    sign_in_as @reporter

    assert_difference -> { Incident.count } => 1 do
      post incidents_url, params: {
        incident: { equipment_id: @equipment.id, description: 'Détecteur bruyant', severity: 'major', nature: 'technical' }
      }
    end

    incident = Incident.last
    assert_redirected_to incident_url(incident)
    assert_equal @reporter, incident.reported_by
    assert incident.declared?
    assert_equal 1, incident.status_changes.count
    assert_nil incident.status_changes.first.from_status
    assert_equal 'declared', incident.status_changes.first.to_status
  end

  test 'un déclarant ne déclare pas dans un autre département' do
    sign_in_as @reporter

    assert_no_difference -> { Incident.count } do
      post incidents_url,
           params: { incident: { equipment_id: @lab_equipment.id, description: 'Panne', severity: 'minor' } }
    end

    assert_redirected_to root_path
  end

  test 'une déclaration sans description réaffiche le formulaire' do
    sign_in_as @reporter

    assert_no_difference -> { Incident.count } do
      post incidents_url, params: { incident: { equipment_id: @equipment.id, description: '', severity: 'minor' } }
    end

    assert_response :unprocessable_entity
  end

  test 'le formulaire de déclaration ne propose que les équipements du département' do
    sign_in_as @reporter

    get new_incident_url

    assert_response :success
    assert_includes response.body, @equipment.code
    assert_not_includes response.body, @lab_equipment.code
  end

  # --- Changements de statut

  test "le responsable technique qualifie un incident critique et l'équipement passe en panne" do
    incident = declare
    sign_in_as @manager

    post transition_incident_url(incident), params: {
      to: 'qualified', comment: 'Confirmé',
      incident: { severity: 'critical', nature: 'technical', assigned_to_id: @technician.id }
    }

    assert_redirected_to incident_url(incident)
    incident.reload
    assert incident.qualified?
    assert_equal @technician, incident.assigned_to
    assert incident.severity_critical?
    assert @equipment.reload.out_of_order?
  end

  test 'une qualification sans personne assignée est refusée' do
    incident = declare
    sign_in_as @manager

    post transition_incident_url(incident), params: { to: 'qualified', incident: { severity: 'major' } }

    assert_response :unprocessable_entity
    assert incident.reload.declared?
  end

  test "le technicien assigné prend en charge puis résout l'incident" do
    incident = declare
    incident.update_columns(status: 'qualified', assigned_to_id: @technician.id)
    sign_in_as @technician

    post transition_incident_url(incident), params: { to: 'in_progress' }
    assert incident.reload.in_progress?

    post transition_incident_url(incident),
         params: { to: 'resolved', incident: { corrective_action: 'Câble remplacé' } }
    incident.reload
    assert incident.resolved?
    assert_equal 'Câble remplacé', incident.corrective_action
  end

  test 'un technicien non assigné ne peut pas changer le statut' do
    incident = declare
    incident.update_columns(status: 'qualified', assigned_to_id: @technician.id)
    sign_in_as @other_technician

    post transition_incident_url(incident), params: { to: 'in_progress' }

    assert_redirected_to root_path
    assert incident.reload.qualified?
  end

  test 'le technicien assigné ne peut pas clôturer' do
    incident = declare
    incident.update_columns(status: 'resolved', assigned_to_id: @technician.id)
    sign_in_as @technician

    post transition_incident_url(incident), params: { to: 'closed', incident: { root_cause: 'Usure' } }

    assert_redirected_to incident_url(incident)
    assert incident.reload.resolved?
  end

  test 'la clôture exige une cause racine' do
    incident = declare
    incident.update_columns(status: 'resolved', assigned_to_id: @technician.id)
    sign_in_as @manager

    post transition_incident_url(incident), params: { to: 'closed' }
    assert_response :unprocessable_entity
    assert incident.reload.resolved?

    post transition_incident_url(incident), params: { to: 'closed', incident: { root_cause: 'Usure du câble' } }
    assert_redirected_to incident_url(incident)
    assert incident.reload.closed?
  end

  # --- Modification

  test 'le responsable technique modifie la nature et la déclaration obligatoire' do
    incident = declare
    sign_in_as @manager

    patch incident_url(incident), params: { incident: { nature: 'safety', mandatory_declaration: '1' } }

    assert_redirected_to incident_url(incident)
    incident.reload
    assert incident.nature_safety?
    assert incident.mandatory_declaration?
  end

  test 'un technicien ne modifie pas un incident' do
    incident = declare
    incident.update_columns(assigned_to_id: @technician.id)
    sign_in_as @technician

    patch incident_url(incident), params: { incident: { description: 'Modifié' } }

    assert_redirected_to root_path
    assert_equal 'Panne alpha', incident.reload.description
  end

  # --- Consultation

  test "la fiche affiche l'historique et l'avertissement de déclaration" do
    incident = declare(nature: :radiation_protection)
    incident.status_changes.create!(to_status: 'declared', user: @reporter, comment: 'Déclaration')
    sign_in_as @reporter

    get incident_url(incident)

    assert_response :success
    assert_includes response.body, 'Historique des statuts'
    assert_includes response.body, 'déclaration obligatoire'
  end

  test 'la fiche équipement liste ses incidents' do
    declare(description: 'Panne alpha')
    sign_in_as @reporter

    get equipment_url(@equipment)

    assert_response :success
    assert_includes response.body, 'Panne alpha'
  end
end
