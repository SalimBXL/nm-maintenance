require "test_helper"

class DashboardSummaryTest < ActiveSupport::TestCase
  setup do
    @cameras = Department.create!(name: "Caméras", code: "CAM")
    @labs = Department.create!(name: "Laboratoires", code: "LABO")
    @camera1 = Location.create!(department: @cameras, name: "Caméra 1", code: "CAM1")
    @lab_room = Location.create!(department: @labs, name: "Labo chaud", code: "LC")
    category = EquipmentCategory.create!(name: "SPECT", code_prefix: "SPECT")
    manufacturer = Manufacturer.create!(name: "GE", code: "GE")
    @model = EquipmentModel.create!(manufacturer: manufacturer, category: category, name: "Modèle A")

    @in_service1 = Equipment.create!(equipment_model: @model, location: @camera1)
    @in_service2 = Equipment.create!(equipment_model: @model, location: @camera1)
    @broken = Equipment.create!(equipment_model: @model, location: @lab_room, status: :out_of_order)
    @retired = Equipment.create!(equipment_model: @model, location: @lab_room, status: :decommissioned, decommissioned_on: Time.zone.today)

    @manager = User.create!(name: "Responsable", email_address: "resp@example.com", password: "secret", role: :technical_manager)
    @technician = User.create!(name: "Technicien", email_address: "tech@example.com", password: "secret", role: :technician)
    @reporter = User.create!(name: "Déclarant", email_address: "decl@example.com", password: "secret")
  end

  def summary(user = @manager)
    DashboardSummary.new(user)
  end

  def declare(equipment: @in_service1, severity: :minor, **attributes)
    Incident.create!({ equipment: equipment, reported_by: @reporter, description: "Panne", severity: severity }.merge(attributes))
  end

  def plan_event(**attributes)
    Event.create!({ equipment: @in_service1, title: "Révision" }.merge(attributes))
  end

  def attach_pdf(document)
    document.file.attach(io: StringIO.new("%PDF-1.4 contenu"), filename: "doc.pdf", content_type: "application/pdf")
    document
  end

  # --- Parc

  test "le parc est compté par statut, archivés exclus" do
    @in_service2.archive!

    assert_equal({ "in_service" => 1, "out_of_order" => 1, "under_maintenance" => 0, "decommissioned" => 1 },
                 summary.equipment_by_status)
    assert_equal 3, summary.equipment_total
  end

  test "la part en service ignore les équipements hors service" do
    assert_equal 67, summary.in_service_percent # 2 en service sur 3 actifs
  end

  test "la part en service est vide sans équipement actif" do
    Equipment.update_all(archived_at: Time.current)

    assert_nil summary.in_service_percent
  end

  # --- Incidents

  test "les incidents ouverts sont comptés par gravité et les clôturés exclus" do
    declare(severity: :critical)
    declare(severity: :major)
    declare(severity: :major)
    declare(severity: :minor).update_columns(status: "closed")

    assert_equal({ "critical" => 1, "major" => 2, "minor" => 0 }, summary.open_incidents_by_severity)
    assert_equal 3, summary.open_incidents_total
  end

  test "les incidents à qualifier sont ceux au statut déclaré" do
    declare
    declare.update_columns(status: "qualified", assigned_to_id: @technician.id)

    assert_equal 1, summary.incidents_to_qualify_count
  end

  test "les incidents urgents sont les critiques puis les majeurs, mineurs exclus" do
    minor = declare(severity: :minor)
    major = declare(severity: :major)
    critical = declare(severity: :critical)

    urgent = summary.urgent_incidents.to_a

    assert_equal [critical, major], urgent
    assert_not_includes urgent, minor
  end

  # --- Interventions

  test "les interventions sont comptées en cours, à venir et en retard" do
    today = Time.zone.today
    plan_event(scheduled_on: today + 2)
    plan_event(scheduled_on: today + 30)
    plan_event(scheduled_on: today - 3)
    plan_event.update_columns(status: "in_progress")
    plan_event(scheduled_on: today - 10).update_columns(status: "completed")

    assert_equal 1, summary.events_in_progress_count
    assert_equal 1, summary.events_upcoming_count
    assert_equal 1, summary.events_overdue_count
  end

  # --- Documents

  test "les documents expirés ou qui expirent bientôt sont comptés, versions remplacées exclues" do
    today = Time.zone.today
    attach_pdf(Document.new(title: "Expiré", equipment: @in_service1, valid_until: today - 1)).save!
    attach_pdf(Document.new(title: "Bientôt", equipment: @in_service1, valid_until: today + 20)).save!
    attach_pdf(Document.new(title: "Loin", equipment: @in_service1, valid_until: today + 400)).save!
    old = attach_pdf(Document.new(title: "Ancien", equipment: @in_service1, valid_until: today - 50)).tap(&:save!)
    attach_pdf(Document.new(title: "Ancien", equipment: @in_service1, supersedes: old, valid_until: today + 500)).save!

    assert_equal 1, summary.documents_expired_count
    assert_equal 1, summary.documents_expiring_count
  end

  # --- Par département

  test "la vue par département compte équipements, pannes et incidents ouverts" do
    declare(equipment: @broken)
    declare(equipment: @in_service1)

    rows = summary.departments_overview.index_by { |row| row[:department] }

    assert_equal({ equipments: 2, out_of_order: 0, open_incidents: 1 }, rows[@cameras].except(:department))
    assert_equal({ equipments: 2, out_of_order: 1, open_incidents: 1 }, rows[@labs].except(:department)) # en panne + hors service (non archivé)
  end

  # --- Tâches de l'utilisateur

  test "le responsable technique voit les incidents à qualifier" do
    declare

    task = summary(@manager).my_tasks.find { |entry| entry[:title] == "Incidents à qualifier" }

    assert_equal 1, task[:total]
  end

  test "le technicien voit ses incidents assignés et ses interventions" do
    mine = declare
    mine.update_columns(status: "qualified", assigned_to_id: @technician.id)
    declare
    plan_event(performed_by: @technician)
    plan_event

    tasks = summary(@technician).my_tasks.index_by { |entry| entry[:title] }

    assert_equal [mine], tasks["Incidents qui me sont assignés"][:records].to_a
    assert_equal 1, tasks["Mes interventions en attente ou en cours"][:total]
    assert_nil tasks["Incidents à qualifier"]
  end

  test "le déclarant voit ses incidents ouverts" do
    declare
    declare.update_columns(status: "closed")

    tasks = summary(@reporter).my_tasks

    assert_equal ["Mes incidents ouverts"], tasks.map { |entry| entry[:title] }
    assert_equal 1, tasks.first[:total]
  end
end
