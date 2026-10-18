require 'test_helper'

class EventPolicyTest < ActiveSupport::TestCase
  setup do
    department = Department.create!(name: 'Caméras', code: 'CAM')
    location = Location.create!(department: department, name: 'Caméra 1', code: 'CAM1')
    category = EquipmentCategory.create!(name: 'SPECT', code_prefix: 'SPECT')
    manufacturer = Manufacturer.create!(name: 'GE', code: 'GE')
    model = EquipmentModel.create!(manufacturer: manufacturer, category: category, name: 'Modèle A')
    @equipment = Equipment.create!(equipment_model: model, location: location)

    @admin = make_user(:admin)
    @manager = make_user(:technical_manager)
    @technician = make_user(:technician)
    @other_technician = User.create!(name: 'Autre', email_address: 'autre@example.com', password: 'secret',
                                     role: :technician)
    @reporter = make_user(:reporter)
  end

  def make_user(role)
    User.create!(name: role.to_s, email_address: "#{role}@example.com", password: 'secret', role: role)
  end

  def event(status: 'planned', performed_by: nil)
    record = Event.create!(equipment: @equipment, title: 'Révision')
    record.update_columns(status: status, performed_by_id: performed_by&.id)
    record
  end

  def assigned_incident(to:, status: 'qualified')
    incident = Incident.create!(equipment: @equipment, reported_by: @reporter, description: 'Panne')
    incident.update_columns(status: status, assigned_to_id: to.id)
    incident
  end

  # --- Lecture

  test 'tout utilisateur actif consulte les interventions' do
    [@admin, @manager, @technician, @reporter].each do |user|
      assert EventPolicy.new(user, Event).index?
      assert EventPolicy.new(user, event).show?
    end
    assert_not EventPolicy.new(nil, Event).index?
  end

  # --- Création

  test 'administrateur et responsable technique planifient' do
    [@admin, @manager].each do |user|
      assert EventPolicy.new(user, Event).create?
      assert EventPolicy.new(user, Event.new(equipment: @equipment)).create?
    end
  end

  test 'le technicien saisit une intervention sur un incident qui lui est assigné' do
    incident = assigned_incident(to: @technician)

    assert EventPolicy.new(@technician, Event.new(incident: incident, equipment: @equipment)).create?
    assert_not EventPolicy.new(@other_technician, Event.new(incident: incident, equipment: @equipment)).create?
  end

  test 'le technicien ne planifie pas sans incident assigné ni sur un incident clôturé' do
    closed = assigned_incident(to: @technician, status: 'closed')

    assert_not EventPolicy.new(@technician, Event).create?
    assert_not EventPolicy.new(@technician, Event.new(equipment: @equipment)).create?
    assert_not EventPolicy.new(@technician, Event.new(incident: closed, equipment: @equipment)).create?
  end

  test "un déclarant ne crée pas d'intervention" do
    incident = assigned_incident(to: @technician)

    assert_not EventPolicy.new(@reporter, Event.new(incident: incident, equipment: @equipment)).create?
  end

  # --- Modification

  test 'le responsable technique modifie toute intervention' do
    assert EventPolicy.new(@manager, event(status: 'completed')).update?
  end

  test "le technicien modifie ses interventions tant qu'elles ne sont pas terminées" do
    assert EventPolicy.new(@technician, event(performed_by: @technician)).update?
    assert EventPolicy.new(@technician, event(status: 'in_progress', performed_by: @technician)).update?
    assert_not EventPolicy.new(@technician, event(status: 'completed', performed_by: @technician)).update?
    assert_not EventPolicy.new(@technician, event(performed_by: @other_technician)).update?
    assert_not EventPolicy.new(@reporter, event).update?
  end

  # --- Changements de statut

  test 'le responsable technique a toutes les transitions' do
    assert_equal %w[in_progress completed cancelled], EventPolicy.new(@manager, event).allowed_targets
    assert_equal %w[completed cancelled], EventPolicy.new(@manager, event(status: 'in_progress')).allowed_targets
    assert_empty EventPolicy.new(@manager, event(status: 'completed')).allowed_targets
  end

  test 'le technicien intervenant démarre et termine, sans annuler' do
    planned = event(performed_by: @technician)

    assert_equal %w[in_progress completed], EventPolicy.new(@technician, planned).allowed_targets
    assert_empty EventPolicy.new(@other_technician, planned).allowed_targets
    assert_empty EventPolicy.new(@reporter, planned).allowed_targets
  end
end
