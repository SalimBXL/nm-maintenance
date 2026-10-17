require 'test_helper'

class IncidentPolicyTest < ActiveSupport::TestCase
  setup do
    @cameras = Department.create!(name: 'Caméras', code: 'CAM')
    @labs = Department.create!(name: 'Laboratoires', code: 'LABO')
    location = Location.create!(department: @cameras, name: 'Caméra 1', code: 'CAM1')
    category = EquipmentCategory.create!(name: 'SPECT', code_prefix: 'SPECT')
    manufacturer = Manufacturer.create!(name: 'GE', code: 'GE')
    model = EquipmentModel.create!(manufacturer: manufacturer, category: category, name: 'Modèle A')
    @equipment = Equipment.create!(equipment_model: model, location: location)

    @admin = make_user(:admin)
    @manager = make_user(:technical_manager)
    @technician = make_user(:technician)
    @reporter = make_user(:reporter)
    DepartmentMembership.create!(user: @reporter, department: @cameras)
    DepartmentMembership.create!(user: @technician, department: @cameras)
  end

  def make_user(role)
    User.create!(name: role.to_s, email_address: "#{role}@example.com", password: 'secret', role: role)
  end

  def incident(status: 'declared', assigned_to: nil)
    record = Incident.create!(equipment: @equipment, reported_by: @reporter, description: 'Panne')
    record.update_columns(status: status, assigned_to_id: assigned_to&.id)
    record
  end

  # --- Déclaration

  test 'administrateur et responsable technique déclarent partout' do
    [@admin, @manager].each do |user|
      assert IncidentPolicy.new(user, Incident.new(equipment: @equipment)).create?
    end
  end

  test 'technicien et déclarant déclarent dans leurs départements' do
    [@technician, @reporter].each do |user|
      assert IncidentPolicy.new(user, Incident.new(equipment: @equipment)).create?
      assert IncidentPolicy.new(user, Incident).create?
    end
  end

  test "un déclarant ne déclare pas sur un équipement d'un autre département" do
    DepartmentMembership.where(user: @reporter).destroy_all
    DepartmentMembership.create!(user: @reporter, department: @labs)

    assert_not IncidentPolicy.new(@reporter, Incident.new(equipment: @equipment)).create?
  end

  test 'sans appartenance à un département, pas de déclaration' do
    lonely = User.create!(name: 'Seul', email_address: 'seul@example.com', password: 'secret', role: :technician)

    assert_not IncidentPolicy.new(lonely, Incident.new(equipment: @equipment)).create?
  end

  test 'un utilisateur non actif ou absent ne déclare pas' do
    @manager.update!(valid_until: Time.zone.today - 1)

    assert_not IncidentPolicy.new(@manager, Incident).create?
    assert_not IncidentPolicy.new(nil, Incident).create?
  end

  # --- Lecture et modification

  test 'tout utilisateur actif consulte les incidents' do
    [@admin, @manager, @technician, @reporter].each do |user|
      assert IncidentPolicy.new(user, Incident).index?
      assert IncidentPolicy.new(user, incident).show?
    end
  end

  test 'seuls administrateur et responsable technique modifient un incident non clôturé' do
    assert IncidentPolicy.new(@manager, incident).update?
    assert IncidentPolicy.new(@admin, incident).update?
    assert_not IncidentPolicy.new(@technician, incident(assigned_to: @technician)).update?
    assert_not IncidentPolicy.new(@reporter, incident).update?
    assert_not IncidentPolicy.new(@manager, incident(status: 'closed', assigned_to: @technician)).update?
  end

  # --- Changements de statut

  test 'le responsable technique a toutes les transitions du workflow' do
    assert_equal %w[qualified], IncidentPolicy.new(@manager, incident).allowed_targets
    assert_equal %w[closed in_progress],
                 IncidentPolicy.new(@manager, incident(status: 'resolved', assigned_to: @technician)).allowed_targets
  end

  test 'le technicien assigné prend en charge et résout, sans qualifier ni clôturer' do
    qualified = incident(status: 'qualified', assigned_to: @technician)
    in_progress = incident(status: 'in_progress', assigned_to: @technician)
    declared = incident(assigned_to: @technician)
    resolved = incident(status: 'resolved', assigned_to: @technician)

    assert_equal %w[in_progress], IncidentPolicy.new(@technician, qualified).allowed_targets
    assert_equal %w[resolved], IncidentPolicy.new(@technician, in_progress).allowed_targets
    assert_empty IncidentPolicy.new(@technician, declared).allowed_targets
    assert_equal %w[in_progress], IncidentPolicy.new(@technician, resolved).allowed_targets
  end

  test "un technicien non assigné et un déclarant n'ont aucune transition" do
    assigned_to_other = incident(status: 'qualified', assigned_to: @manager)

    assert_empty IncidentPolicy.new(@technician, assigned_to_other).allowed_targets
    assert_empty IncidentPolicy.new(@reporter, assigned_to_other).allowed_targets
    assert_not IncidentPolicy.new(@reporter, assigned_to_other).transition?
  end
end
