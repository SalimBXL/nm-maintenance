# Chiffres du tableau de bord : un instantané de l'état du parc, des
# incidents, des interventions et des documents, plus les tâches de
# l'utilisateur. Rien n'est stocké : tout est calculé à l'affichage.
class DashboardSummary
  UPCOMING_DAYS = 7
  TASKS_SHOWN = 5

  def initialize(user, today: Time.zone.today)
    @user = user
    @today = today
  end

  # --- Parc

  def equipment_by_status
    counts = Equipment.kept.group(:status).count
    Equipment.statuses.keys.index_with { |status| counts.fetch(status, 0) }
  end

  def equipment_total
    equipment_by_status.values.sum
  end

  # Part des équipements en service parmi ceux qui ne sont pas hors service
  # (instantané, pas un indicateur de disponibilité sur une période).
  def in_service_percent
    active = equipment_total - equipment_by_status['decommissioned']
    return nil if active.zero?

    (equipment_by_status['in_service'] * 100.0 / active).round
  end

  # --- Incidents

  def open_incidents_by_severity
    counts = Incident.unclosed.group(:severity).count
    Incident.severities.keys.index_with { |severity| counts.fetch(severity, 0) }
  end

  def open_incidents_total
    open_incidents_by_severity.values.sum
  end

  def incidents_to_qualify_count
    Incident.where(status: 'declared').count
  end

  # Incidents critiques puis majeurs encore ouverts, les plus anciens d'abord.
  def urgent_incidents(limit: 8)
    Incident.unclosed.where(severity: %w[critical major])
            .includes(equipment: { location: :department })
            .order(Arel.sql("CASE incidents.severity WHEN 'critical' THEN 0 ELSE 1 END"), :detected_at)
            .limit(limit)
  end

  # --- Interventions

  def events_in_progress_count
    Event.where(status: 'in_progress').count
  end

  def events_upcoming_count
    Event.where(status: 'planned', scheduled_on: @today..(@today + UPCOMING_DAYS)).count
  end

  # Planifiées dont la date prévue est dépassée.
  def events_overdue_count
    Event.where(status: 'planned').where(scheduled_on: ...@today).count
  end

  # --- Documents (versions actuelles non archivées)

  def documents_expired_count
    current_documents.where(valid_until: ...@today).count
  end

  def documents_expiring_count
    current_documents.where(valid_until: @today..(@today + Document::EXPIRING_DAYS)).count
  end

  # --- Par département

  def departments_overview
    totals = Equipment.kept.joins(:location).group('locations.department_id').count
    down = Equipment.kept.where(status: 'out_of_order').joins(:location).group('locations.department_id').count
    incidents = Incident.unclosed.joins(equipment: :location).group('locations.department_id').count

    Department.kept.order(:name).map do |department|
      {
        department: department,
        equipments: totals.fetch(department.id, 0),
        out_of_order: down.fetch(department.id, 0),
        open_incidents: incidents.fetch(department.id, 0)
      }
    end
  end

  # --- Tâches de l'utilisateur : [{ title:, total:, records: }]

  def my_tasks
    tasks = []
    tasks << task('Incidents à qualifier', Incident.where(status: 'declared')) if manager?

    if @user.reporter?
      tasks << task('Mes incidents ouverts', Incident.unclosed.where(reported_by_id: @user.id))
    else
      tasks << task('Incidents qui me sont assignés', Incident.unclosed.where(assigned_to_id: @user.id))
      tasks << task('Mes interventions en attente ou en cours', Event.open_ones.where(performed_by_id: @user.id))
    end

    tasks
  end

  private

  def manager?
    @user.admin? || @user.technical_manager?
  end

  def current_documents
    Document.current.kept
  end

  def task(title, scope)
    { title: title, total: scope.count, records: scope.includes(:equipment).order(:id).limit(TASKS_SHOWN) }
  end
end
