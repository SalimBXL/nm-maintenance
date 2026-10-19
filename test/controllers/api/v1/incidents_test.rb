require_relative 'api_test_case'

class ApiIncidentsTest < ApiTestCase
  def declare(description: 'Panne alpha', equipment: @equipment, **attributes)
    Incident.create!({ equipment: equipment, reported_by: @reporter, description: description,
                       severity: :major }.merge(attributes))
  end

  # --- Déclaration

  test 'un déclarant déclare un incident dans son département' do
    assert_difference -> { Incident.count } => 1 do
      post api_v1_incidents_url, headers: auth(@reporter), as: :json, params: {
        incident: { equipment_id: @equipment.id, description: 'Détecteur bruyant', severity: 'major', nature: 'technical' }
      }
    end

    assert_response :created
    data = json['data']
    assert_equal 'declared', data['status']
    assert_equal 'major', data['severity']
    assert_equal @equipment.code, data['equipment']['code']
    assert_equal @reporter.id, data['reported_by']['id']
    assert_equal [], data['allowed_transitions']

    incident = Incident.last
    assert_equal 1, incident.status_changes.count
    assert_equal 'declared', incident.status_changes.first.to_status
  end

  test 'un déclarant ne déclare pas dans un autre département' do
    assert_no_difference -> { Incident.count } do
      post api_v1_incidents_url, headers: auth(@reporter), as: :json, params: {
        incident: { equipment_id: @lab_equipment.id, description: 'Panne' }
      }
    end

    assert_response :forbidden
    assert_equal 'forbidden', json['error']['code']
  end

  test 'une déclaration invalide répond 422 avec le détail par champ' do
    post api_v1_incidents_url, headers: auth(@reporter), as: :json, params: {
      incident: { equipment_id: @equipment.id, description: '' }
    }

    assert_response :unprocessable_entity
    assert_equal 'validation_failed', json['error']['code']
    assert json['error']['details']['description'].present?
  end

  test "un corps sans l'objet incident répond 400" do
    post api_v1_incidents_url, headers: auth(@reporter), as: :json, params: { sans_rapport: 'x' }

    assert_response :bad_request
    assert_equal 'bad_request', json['error']['code']
  end

  test 'la déclaration exige un jeton' do
    post api_v1_incidents_url, as: :json, params: { incident: { equipment_id: @equipment.id, description: 'Panne' } }

    assert_response :unauthorized
  end

  # --- Consultation

  test 'la liste affiche par défaut les incidents ouverts' do
    declare(description: 'Panne alpha')
    declare(description: 'Panne beta').update_columns(status: 'closed')

    get api_v1_incidents_url, headers: auth(@reporter)
    assert_equal(['Panne alpha'], json['data'].map { |incident| incident['description'] })

    get api_v1_incidents_url(status: 'all'), headers: auth(@reporter)
    assert_equal 2, json['data'].size
  end

  test 'filtres par gravité et par incidents personnels' do
    declare(description: 'Panne alpha', severity: :critical)
    mine = declare(description: 'Panne beta', severity: :minor)
    mine.update_columns(status: 'qualified', assigned_to_id: @technician.id)

    get api_v1_incidents_url(severity: 'critical'), headers: auth(@reporter)
    assert_equal(['Panne alpha'], json['data'].map { |incident| incident['description'] })

    get api_v1_incidents_url(mine: '1'), headers: auth(@technician)
    assert_equal(['Panne beta'], json['data'].map { |incident| incident['description'] })
  end

  test "la fiche d'un incident indique les transitions permises à l'utilisateur" do
    incident = declare

    get api_v1_incident_url(incident), headers: auth(@manager)
    assert_equal ['qualified'], json['data']['allowed_transitions']

    get api_v1_incident_url(incident), headers: auth(@reporter)
    assert_equal [], json['data']['allowed_transitions']
  end

  # --- Changements de statut

  test "le responsable technique qualifie un incident critique et l'équipement passe en panne" do
    incident = declare

    post transition_api_v1_incident_url(incident), headers: auth(@manager), as: :json, params: {
      to: 'qualified', comment: 'Confirmé',
      incident: { severity: 'critical', assigned_to_id: @technician.id }
    }

    assert_response :success
    assert_equal 'qualified', json['data']['status']
    assert_equal @technician.id, json['data']['assigned_to']['id']
    assert @equipment.reload.out_of_order?
  end

  test 'une qualification sans personne assignée répond 422' do
    incident = declare

    post transition_api_v1_incident_url(incident), headers: auth(@manager), as: :json, params: { to: 'qualified' }

    assert_response :unprocessable_entity
    assert json['error']['details']['assigned_to'].present?
    assert incident.reload.declared?
  end

  test 'un technicien non assigné ne change pas le statut' do
    incident = declare
    incident.update_columns(status: 'qualified', assigned_to_id: @manager.id)

    post transition_api_v1_incident_url(incident), headers: auth(@technician), as: :json, params: { to: 'in_progress' }

    assert_response :forbidden
    assert incident.reload.qualified?
  end

  test 'le technicien assigné prend en charge puis résout, sans clôturer' do
    incident = declare
    incident.update_columns(status: 'qualified', assigned_to_id: @technician.id)
    headers = auth(@technician)

    post transition_api_v1_incident_url(incident), headers: headers, as: :json, params: { to: 'in_progress' }
    assert_response :success

    post transition_api_v1_incident_url(incident), headers: headers, as: :json, params: { to: 'resolved' }
    assert_response :success

    post transition_api_v1_incident_url(incident), headers: headers, as: :json, params: { to: 'closed' }
    assert_response :forbidden
    assert incident.reload.resolved?
  end
end
