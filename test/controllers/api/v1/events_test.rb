require_relative 'api_test_case'

class ApiEventsTest < ApiTestCase
  def plan(title: 'Révision alpha', **attributes)
    Event.create!({ equipment: @equipment, title: title, event_type: :preventive }.merge(attributes))
  end

  def assigned_incident(to: @technician)
    incident = Incident.create!(equipment: @equipment, reported_by: @reporter, description: 'Panne détecteur')
    incident.update_columns(status: 'qualified', assigned_to_id: to.id)
    incident
  end

  # --- Consultation

  test 'la liste exige un jeton' do
    get api_v1_events_url

    assert_response :unauthorized
  end

  test 'la liste affiche par défaut les interventions en attente ou en cours' do
    plan(title: 'Révision alpha')
    plan(title: 'Révision beta').update_columns(status: 'completed')

    get api_v1_events_url, headers: auth(@reporter)
    assert_equal(['Révision alpha'], json['data'].map { |event| event['title'] })

    get api_v1_events_url(status: 'all'), headers: auth(@reporter)
    assert_equal 2, json['data'].size
  end

  test 'filtres par type et par intervenant' do
    plan(title: 'Révision alpha', event_type: :preventive)
    plan(title: 'Étalonnage gamma', event_type: :calibration, performed_by: @technician)

    get api_v1_events_url(event_type: 'calibration'), headers: auth(@reporter)
    assert_equal(['Étalonnage gamma'], json['data'].map { |event| event['title'] })

    get api_v1_events_url(mine: '1'), headers: auth(@technician)
    assert_equal(['Étalonnage gamma'], json['data'].map { |event| event['title'] })
  end

  test "la fiche d'une intervention" do
    event = plan(performed_by: @technician)

    get api_v1_event_url(event), headers: auth(@technician)

    assert_response :success
    data = json['data']
    assert_equal 'Révision alpha', data['title']
    assert_equal 'planned', data['status']
    assert_equal %w[in_progress completed], data['allowed_transitions']
  end

  # --- Création

  test 'le responsable technique planifie une intervention' do
    assert_difference -> { Event.count } => 1 do
      post api_v1_events_url, headers: auth(@manager), as: :json, params: {
        event: { equipment_id: @equipment.id, event_type: 'calibration', title: 'Étalonnage annuel',
                 scheduled_on: '2026-11-15', performed_by_id: @technician.id }
      }
    end

    assert_response :created
    data = json['data']
    assert_equal 'planned', data['status']
    assert_equal 'calibration', data['event_type']
    assert_equal @technician.id, data['performed_by']['id']
    assert_equal '2026-11-15', data['scheduled_on']
  end

  test 'le technicien saisit une intervention sur un incident qui lui est assigné' do
    incident = assigned_incident

    post api_v1_events_url, headers: auth(@technician), as: :json, params: {
      event: { incident_id: incident.id, event_type: 'corrective', title: 'Remplacement du câble' }
    }

    assert_response :created
    event = Event.last
    assert_equal @equipment, event.equipment
    assert_equal @technician, event.performed_by
    assert_equal incident, event.incident
  end

  test "le technicien ne crée pas d'intervention sans incident assigné" do
    assert_no_difference -> { Event.count } do
      post api_v1_events_url, headers: auth(@technician), as: :json, params: {
        event: { equipment_id: @equipment.id, title: 'Révision' }
      }
    end

    assert_response :forbidden
  end

  test 'une création invalide répond 422' do
    post api_v1_events_url, headers: auth(@manager), as: :json, params: { event: { equipment_id: @equipment.id, title: '' } }

    assert_response :unprocessable_entity
    assert json['error']['details']['title'].present?
  end

  # --- Déroulement

  test 'le technicien intervenant démarre puis termine avec rapport, durée et coût' do
    event = plan(performed_by: @technician)
    headers = auth(@technician)

    post start_api_v1_event_url(event), headers: headers, as: :json
    assert_response :success
    assert_equal 'in_progress', json['data']['status']

    post complete_api_v1_event_url(event), headers: headers, as: :json, params: {
      event: { report: 'Câble remplacé, test réussi', downtime_minutes: 90, cost_euros: '120,50' }
    }

    assert_response :success
    data = json['data']
    assert_equal 'completed', data['status']
    assert_equal 90, data['downtime_minutes']
    assert_equal 12_050, data['cost_cents']
    assert_equal [], data['allowed_transitions']
  end

  test 'terminer sans rapport répond 422' do
    event = plan(performed_by: @technician)

    post complete_api_v1_event_url(event), headers: auth(@technician), as: :json, params: { event: { report: '' } }

    assert_response :unprocessable_entity
    assert json['error']['details']['report'].present?
    assert event.reload.planned?
  end

  test 'un technicien non intervenant ne change pas le statut' do
    event = plan(performed_by: @manager)

    post start_api_v1_event_url(event), headers: auth(@technician), as: :json

    assert_response :forbidden
    assert event.reload.planned?
  end

  test 'annuler est réservé au responsable technique' do
    event = plan(performed_by: @technician)

    post cancel_api_v1_event_url(event), headers: auth(@technician), as: :json
    assert_response :forbidden

    post cancel_api_v1_event_url(event), headers: auth(@manager), as: :json,
                                         params: { event: { report: 'Reportée' } }
    assert_response :success
    assert_equal 'cancelled', json['data']['status']
  end
end
