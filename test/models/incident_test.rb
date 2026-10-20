require 'test_helper'

class IncidentTest < ActiveSupport::TestCase
  setup do
    department = Department.create!(name: 'Caméras', code: 'CAM')
    location = Location.create!(department: department, name: 'Caméra 1', code: 'CAM1')
    category = EquipmentCategory.create!(name: 'SPECT', code_prefix: 'SPECT')
    manufacturer = Manufacturer.create!(name: 'GE', code: 'GE')
    model = EquipmentModel.create!(manufacturer: manufacturer, category: category, name: 'Modèle A')
    @equipment = Equipment.create!(equipment_model: model, location: location)

    @reporter = User.create!(name: 'Déclarant', email_address: 'decl@example.com', password: 'secret')
    @technician = User.create!(name: 'Technicien', email_address: 'tech@example.com', password: 'secret',
                               role: :technician)
    @manager = User.create!(name: 'Responsable', email_address: 'resp@example.com', password: 'secret',
                            role: :technical_manager)
  end

  def declare(**attributes)
    Incident.create!({ equipment: @equipment, reported_by: @reporter, description: 'Panne',
                       severity: :major }.merge(attributes))
  end

  def qualify(incident)
    assert incident.transition('qualified', user: @manager, attributes: { assigned_to_id: @technician.id })
    incident
  end

  # --- Déclaration

  test 'un incident déclaré a le statut déclaré et une date de détection' do
    incident = declare

    assert incident.declared?
    assert incident.detected_at.present?
  end

  test 'la description est obligatoire' do
    incident = Incident.new(equipment: @equipment, reported_by: @reporter, description: '')

    assert_not incident.valid?
    assert incident.errors[:description].any?
  end

  test "un équipement archivé n'accepte plus d'incident" do
    @equipment.archive!

    assert_not Incident.new(equipment: @equipment, reported_by: @reporter, description: 'Panne').valid?
  end

  # --- Qualification

  test 'la qualification exige une personne assignée' do
    incident = declare

    assert_not incident.transition('qualified', user: @manager)
    assert incident.errors[:assigned_to].any?
    assert incident.reload.declared?
  end

  test 'un déclarant ne peut pas être assigné à un incident' do
    incident = declare

    assert_not incident.transition('qualified', user: @manager, attributes: { assigned_to_id: @reporter.id })
    assert incident.reload.declared?
  end

  test 'la qualification confirme gravité et nature et trace le changement' do
    incident = declare(severity: :minor)

    assert incident.transition('qualified', user: @manager, comment: 'Pris en compte',
                                            attributes: { assigned_to_id: @technician.id,
                                                          severity: 'critical',
                                                          nature: 'safety' })

    incident.reload
    assert incident.qualified?
    assert incident.severity_critical?
    assert incident.nature_safety?

    change = incident.status_changes.last
    assert_equal 'declared', change.from_status
    assert_equal 'qualified', change.to_status
    assert_equal @manager, change.user
    assert_equal 'Pris en compte', change.comment
  end

  # --- Workflow

  test "workflow complet jusqu'à la clôture" do
    incident = qualify(declare)

    assert incident.transition('in_progress', user: @technician)
    assert incident.transition('resolved', user: @technician, attributes: { corrective_action: 'Pièce remplacée' })
    assert incident.resolved_at.present?
    assert incident.transition('closed', user: @manager, attributes: { root_cause: 'Usure' })

    incident.reload
    assert incident.closed?
    assert incident.closed_at.present?
    assert_equal %w[declared qualified in_progress resolved],
                 incident.status_changes.order(:id).map(&:from_status).compact
  end

  test 'la clôture exige une cause racine' do
    incident = qualify(declare)
    incident.transition('in_progress', user: @technician)
    incident.transition('resolved', user: @technician)

    assert_not incident.transition('closed', user: @manager)
    assert incident.errors[:root_cause].any?
    assert incident.reload.resolved?
  end

  test 'les transitions non prévues sont refusées' do
    incident = declare

    assert_not incident.transition('closed', user: @manager)
    assert_not incident.transition('resolved', user: @manager)
    assert incident.reload.declared?
  end

  test "la réouverture d'un incident résolu exige un commentaire" do
    incident = qualify(declare)
    incident.transition('in_progress', user: @technician)
    incident.transition('resolved', user: @technician)

    assert_not incident.transition('in_progress', user: @manager)
    assert incident.transition('in_progress', user: @manager, comment: 'La panne est revenue')

    incident.reload
    assert incident.in_progress?
    assert_nil incident.resolved_at
  end

  test "l'historique des statuts ne peut pas être modifié" do
    incident = qualify(declare)
    change = incident.status_changes.last

    assert_raises(ActiveRecord::ReadOnlyRecord) { change.update!(comment: 'autre') }
    assert_raises(ActiveRecord::ReadOnlyRecord) { change.destroy }
  end

  # --- Effet sur l'équipement

  test "un incident critique qualifié met l'équipement en panne" do
    qualify(declare(severity: :critical))

    assert @equipment.reload.out_of_order?
  end

  test "un incident non critique ne change pas le statut de l'équipement" do
    qualify(declare(severity: :major))

    assert @equipment.reload.in_service?
  end
end
