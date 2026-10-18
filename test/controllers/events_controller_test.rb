require 'test_helper'

class EventsControllerTest < ActionDispatch::IntegrationTest
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
  end

  def make_user(name, role)
    User.create!(name: name, email_address: "#{name.parameterize}@example.com", password: 'secret', role: role)
  end

  def plan(title: 'Révision alpha', equipment: @equipment, **attributes)
    Event.create!({ equipment: equipment, title: title, event_type: :preventive }.merge(attributes))
  end

  def assigned_incident(to: @technician)
    incident = Incident.create!(equipment: @equipment, reported_by: @reporter, description: 'Panne détecteur')
    incident.update_columns(status: 'qualified', assigned_to_id: to.id)
    incident
  end

  # --- Liste

  test 'la liste exige une connexion' do
    get events_url

    assert_redirected_to new_session_url
  end

  test 'la liste affiche par défaut les interventions en attente ou en cours' do
    plan(title: 'Révision alpha')
    done = plan(title: 'Révision beta')
    done.update_columns(status: 'completed')
    sign_in_as @reporter

    get events_url
    assert_includes response.body, 'Révision alpha'
    assert_not_includes response.body, 'Révision beta'

    get events_url(status: 'all')
    assert_includes response.body, 'Révision beta'
  end

  test 'filtre par type et par département' do
    plan(title: 'Révision alpha', event_type: :preventive)
    plan(title: 'Étalonnage gamma', event_type: :calibration, equipment: @lab_equipment)
    sign_in_as @reporter

    get events_url(event_type: 'calibration')
    assert_includes response.body, 'Étalonnage gamma'
    assert_not_includes response.body, 'Révision alpha'

    get events_url(department_id: @cameras.id)
    assert_includes response.body, 'Révision alpha'
    assert_not_includes response.body, 'Étalonnage gamma'
  end

  # --- Planification par le responsable technique

  test 'le responsable technique planifie une intervention' do
    sign_in_as @manager

    assert_difference -> { Event.count } => 1 do
      post events_url, params: {
        event: { equipment_id: @equipment.id, event_type: 'calibration', title: 'Étalonnage annuel',
                 scheduled_on: '2026-11-15', performed_by_id: @technician.id, contractor: 'Prestataire X' }
      }
    end

    event = Event.last
    assert_redirected_to event_url(event)
    assert event.planned?
    assert event.type_calibration?
    assert_equal @technician, event.performed_by
    assert_equal Date.new(2026, 11, 15), event.scheduled_on
  end

  test "une intervention liée à un incident d'un autre équipement est refusée" do
    incident = Incident.create!(equipment: @lab_equipment, reported_by: @reporter, description: 'Panne')
    sign_in_as @manager

    assert_no_difference -> { Event.count } do
      post events_url, params: { event: { equipment_id: @equipment.id, incident_id: incident.id, title: 'Réparation' } }
    end

    assert_response :unprocessable_entity
  end

  test 'un déclarant ne planifie rien' do
    sign_in_as @reporter

    get new_event_url
    assert_redirected_to root_path

    assert_no_difference -> { Event.count } do
      post events_url, params: { event: { equipment_id: @equipment.id, title: 'Révision' } }
    end
  end

  # --- Saisie par le technicien

  test 'le technicien saisit une intervention sur un incident qui lui est assigné' do
    incident = assigned_incident
    sign_in_as @technician

    get new_event_url(incident_id: incident.id)
    assert_response :success

    assert_difference -> { Event.count } => 1 do
      post events_url, params: {
        event: { incident_id: incident.id, event_type: 'corrective', title: 'Remplacement du câble' }
      }
    end

    event = Event.last
    assert_equal @equipment, event.equipment
    assert_equal @technician, event.performed_by
    assert_equal incident, event.incident
  end

  test 'le technicien ne peut pas imposer un autre équipement ni un autre intervenant' do
    incident = assigned_incident
    sign_in_as @technician

    post events_url, params: {
      event: { incident_id: incident.id, equipment_id: @lab_equipment.id, performed_by_id: @manager.id, title: 'Réparation' }
    }

    event = Event.last
    assert_equal @equipment, event.equipment
    assert_equal @technician, event.performed_by
  end

  test "un technicien non assigné à l'incident ne peut pas saisir d'intervention" do
    incident = assigned_incident(to: @other_technician)
    sign_in_as @technician

    assert_no_difference -> { Event.count } do
      post events_url, params: { event: { incident_id: incident.id, title: 'Réparation' } }
    end

    assert_redirected_to root_path
  end

  test "le technicien ne planifie pas d'intervention sans incident" do
    sign_in_as @technician

    get new_event_url

    assert_redirected_to root_path
  end

  # --- Déroulement

  test 'le technicien intervenant démarre puis termine avec rapport, durée et coût' do
    event = plan(performed_by: @technician)
    sign_in_as @technician

    post transition_event_url(event), params: { to: 'in_progress' }
    assert event.reload.in_progress?

    post transition_event_url(event), params: {
      to: 'completed', event: { report: 'Câble remplacé, test réussi', downtime_minutes: '90', cost_euros: '120,50' }
    }

    assert_redirected_to event_url(event)
    event.reload
    assert event.completed?
    assert_equal 'Câble remplacé, test réussi', event.report
    assert_equal 90, event.downtime_minutes
    assert_equal 12_050, event.cost_cents
  end

  test "terminer sans rapport réaffiche la fiche avec l'erreur" do
    event = plan(performed_by: @technician)
    sign_in_as @technician

    post transition_event_url(event), params: { to: 'completed', event: { report: '' } }

    assert_response :unprocessable_entity
    assert event.reload.planned?
  end

  test 'un technicien non intervenant ne change pas le statut' do
    event = plan(performed_by: @technician)
    sign_in_as @other_technician

    post transition_event_url(event), params: { to: 'in_progress' }

    assert_redirected_to root_path
    assert event.reload.planned?
  end

  test 'le technicien intervenant ne peut pas annuler' do
    event = plan(performed_by: @technician)
    sign_in_as @technician

    post transition_event_url(event), params: { to: 'cancelled' }

    assert_redirected_to event_url(event)
    assert event.reload.planned?
  end

  test 'le responsable technique annule une intervention' do
    event = plan
    sign_in_as @manager

    post transition_event_url(event), params: { to: 'cancelled', event: { report: 'Reportée au mois prochain' } }

    assert event.reload.cancelled?
  end

  # --- Modification

  test "le responsable technique assigne l'intervenant" do
    event = plan
    sign_in_as @manager

    patch event_url(event), params: { event: { performed_by_id: @technician.id, scheduled_on: '2026-12-01' } }

    assert_redirected_to event_url(event)
    assert_equal @technician, event.reload.performed_by
  end

  test "le technicien intervenant modifie son rapport mais pas l'intervenant" do
    event = plan(performed_by: @technician)
    sign_in_as @technician

    patch event_url(event), params: { event: { report: 'En cours de test', performed_by_id: @manager.id } }

    event.reload
    assert_equal 'En cours de test', event.report
    assert_equal @technician, event.performed_by
  end

  test "un technicien ne modifie pas l'intervention d'un autre" do
    event = plan(performed_by: @other_technician)
    sign_in_as @technician

    patch event_url(event), params: { event: { report: 'Modifié' } }

    assert_redirected_to root_path
    assert_nil event.reload.report
  end

  # --- Consultation

  test "la fiche de l'intervention s'affiche avec ses actions" do
    event = plan(performed_by: @technician)
    sign_in_as @technician

    get event_url(event)

    assert_response :success
    assert_includes response.body, 'Révision alpha'
    assert_includes response.body, 'Terminer et saisir le rapport'
  end

  test 'la fiche équipement et la fiche incident listent les interventions' do
    incident = assigned_incident
    plan(title: 'Révision alpha')
    plan(title: 'Réparation du câble', incident: incident)
    sign_in_as @manager

    get equipment_url(@equipment)
    assert_includes response.body, 'Révision alpha'

    get incident_url(incident)
    assert_includes response.body, 'Réparation du câble'
    assert_not_includes response.body, 'Révision alpha'
  end
end
