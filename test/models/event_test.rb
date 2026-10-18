require 'test_helper'

class EventTest < ActiveSupport::TestCase
  setup do
    department = Department.create!(name: 'Caméras', code: 'CAM')
    location = Location.create!(department: department, name: 'Caméra 1', code: 'CAM1')
    category = EquipmentCategory.create!(name: 'SPECT', code_prefix: 'SPECT')
    manufacturer = Manufacturer.create!(name: 'GE', code: 'GE')
    model = EquipmentModel.create!(manufacturer: manufacturer, category: category, name: 'Modèle A')
    @equipment = Equipment.create!(equipment_model: model, location: location)
    @other_equipment = Equipment.create!(equipment_model: model, location: location)

    @reporter = User.create!(name: 'Déclarant', email_address: 'decl@example.com', password: 'secret')
    @technician = User.create!(name: 'Technicien', email_address: 'tech@example.com', password: 'secret',
                               role: :technician)
    @manager = User.create!(name: 'Responsable', email_address: 'resp@example.com', password: 'secret',
                            role: :technical_manager)
  end

  def plan(**attributes)
    Event.create!({ equipment: @equipment, title: 'Révision annuelle', event_type: :preventive }.merge(attributes))
  end

  # --- Création

  test 'une intervention est planifiée par défaut' do
    event = plan

    assert event.planned?
    assert event.type_preventive?
  end

  test 'le titre est obligatoire' do
    assert_not Event.new(equipment: @equipment, title: '').valid?
  end

  test "un équipement archivé n'accepte plus d'intervention" do
    @equipment.archive!

    assert_not Event.new(equipment: @equipment, title: 'Révision').valid?
  end

  test "l'incident lié doit concerner le même équipement" do
    incident = Incident.create!(equipment: @other_equipment, reported_by: @reporter, description: 'Panne')

    event = Event.new(equipment: @equipment, title: 'Réparation', incident: incident)
    assert_not event.valid?
    assert event.errors[:incident].any?

    assert Event.new(equipment: @other_equipment, title: 'Réparation', incident: incident).valid?
  end

  test 'un déclarant ne peut pas être intervenant' do
    assert_not Event.new(equipment: @equipment, title: 'Révision', performed_by: @reporter).valid?
    assert Event.new(equipment: @equipment, title: 'Révision', performed_by: @technician).valid?
  end

  # --- Coût et durée

  test 'le coût saisi en euros est stocké en centimes' do
    event = plan(cost_euros: '125,50')
    assert_equal 12_550, event.cost_cents
    assert_equal '125,50', event.cost_euros

    event.cost_euros = '80'
    assert_equal 8_000, event.cost_cents

    event.cost_euros = ''
    assert_nil event.cost_cents
  end

  test 'un coût invalide est refusé' do
    event = Event.new(equipment: @equipment, title: 'Révision', cost_euros: 'beaucoup')

    assert_not event.valid?
    assert event.errors[:cost_euros].any?
  end

  test "une durée d'indisponibilité négative est refusée" do
    assert_not Event.new(equipment: @equipment, title: 'Révision', downtime_minutes: -5).valid?
  end

  # --- Statuts

  test "démarrer renseigne le début et l'intervenant" do
    event = plan

    assert event.transition('in_progress', user: @technician)

    event.reload
    assert event.in_progress?
    assert event.started_at.present?
    assert_equal @technician, event.performed_by
  end

  test 'terminer exige un rapport et renseigne la fin' do
    event = plan

    assert_not event.transition('completed', user: @technician)
    assert event.errors[:report].any?
    assert event.reload.planned?

    assert event.transition('completed', user: @technician,
                                         attributes: { report: 'Câble remplacé', downtime_minutes: 90, cost_euros: '120,50' })

    event.reload
    assert event.completed?
    assert event.ended_at.present?
    assert_equal 90, event.downtime_minutes
    assert_equal 12_050, event.cost_cents
  end

  test 'la fin ne peut pas précéder le début' do
    event = plan
    event.transition('in_progress', user: @technician, attributes: { started_at: Time.current })

    assert_not event.transition('completed', user: @technician,
                                             attributes: { report: 'Fait', ended_at: 2.days.ago })
    assert event.errors[:ended_at].any?
  end

  test 'une intervention peut être annulée mais pas rouverte' do
    event = plan

    assert event.transition('cancelled', user: @manager, attributes: { report: 'Reportée' })
    assert event.reload.cancelled?
    assert_empty event.next_statuses
    assert_not event.transition('in_progress', user: @manager)
  end

  test "une intervention terminée n'a plus de transition" do
    event = plan
    event.transition('completed', user: @technician, attributes: { report: 'Fait' })

    assert_empty event.reload.next_statuses
  end
end
