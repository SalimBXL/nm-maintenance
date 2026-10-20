class IncidentsController < ApplicationController
  PER_PAGE = 50
  OPEN_FIRST = Arel.sql("CASE incidents.status WHEN 'closed' THEN 1 ELSE 0 END")
  SEVERITY_ORDER = Arel.sql("CASE incidents.severity WHEN 'critical' THEN 0 WHEN 'major' THEN 1 ELSE 2 END")

  before_action :set_incident, only: %i[show edit update transition]
  after_action :verify_authorized
  after_action :verify_policy_scoped, only: :index

  def index
    authorize Incident
    scope = filtered(policy_scope(Incident))

    @total = scope.count
    @pages = [(@total / PER_PAGE.to_f).ceil, 1].max
    @page = params[:page].to_i.clamp(1, @pages)
    @incidents = scope
                 .includes({ equipment: { location: :department } }, :assigned_to)
                 .order(OPEN_FIRST, SEVERITY_ORDER, detected_at: :desc)
                 .limit(PER_PAGE).offset((@page - 1) * PER_PAGE)

    @departments = Department.kept.order(:name)
  end

  def show
    authorize @incident
    load_show_data
  end

  def new
    @incident = Incident.new(equipment_id: params[:equipment_id])
    authorize @incident
    load_declaration_data
  end

  def edit
    authorize @incident
    @assignees = assignable_users
  end

  def create
    @incident = Incident.new(declaration_params)
    @incident.reported_by = Current.user
    authorize @incident

    if save_declaration(@incident)
      redirect_to @incident, notice: "L'incident a été déclaré."
    else
      load_declaration_data
      render :new, status: :unprocessable_content
    end
  end

  def update
    authorize @incident

    if @incident.update(qualification_params)
      redirect_to @incident, notice: "L'incident a été mis à jour."
    else
      @assignees = assignable_users
      render :edit, status: :unprocessable_content
    end
  end

  def transition
    authorize @incident, :transition?
    target = params[:to].to_s

    unless policy(@incident).allowed_targets.include?(target)
      redirect_to @incident, alert: "Ce changement de statut n'est pas permis."
      return
    end

    if @incident.transition(target, user: Current.user, comment: params[:comment], attributes: transition_attributes)
      redirect_to @incident, notice: "Statut mis à jour : #{t("enums.incident.status.#{@incident.status}")}."
    else
      load_show_data
      render :show, status: :unprocessable_content
    end
  end

  private

  def set_incident
    @incident = Incident.includes(equipment: { location: :department }).find(params.expect(:id))
  end

  def load_show_data
    @changes = @incident.status_changes.includes(:user).order(:created_at, :id)
    @allowed_targets = policy(@incident).allowed_targets
    @assignees = assignable_users
  end

  def load_declaration_data
    @equipments = declarable_equipments
  end

  # Équipements sur lesquels l'utilisateur peut déclarer un incident.
  def declarable_equipments
    scope = Equipment.kept.includes(:equipment_model, location: :department).order(:code)
    return scope if Current.user.admin? || Current.user.technical_manager?

    scope.where(location_id: Location.where(department_id: Current.user.department_memberships.select(:department_id)))
  end

  def assignable_users
    User.active.where(role: %w[technician technical_manager admin]).order(:name)
  end

  # La déclaration et son premier enregistrement dans l'historique forment un tout.
  def save_declaration(incident)
    IncidentStatusChange.transaction do
      raise ActiveRecord::Rollback unless incident.save

      incident.status_changes.create!(to_status: 'declared', user: Current.user, comment: 'Déclaration')
      true
    end
  end

  def filtered(scope)
    status = params[:status].to_s
    scope = scope.unclosed if status.blank?
    scope = scope.where(status: status) if Incident.statuses.key?(status)
    scope = scope.where(severity: params[:severity]) if Incident.severities.key?(params[:severity])
    scope = scope.where(equipment_id: params[:equipment_id]) if params[:equipment_id].present?
    if params[:department_id].present?
      scope = scope.where(equipment_id: Equipment.where(location_id: Location.where(department_id: params[:department_id])))
    end
    if params[:mine] == '1'
      scope = scope.where('incidents.assigned_to_id = :id OR incidents.reported_by_id = :id', id: Current.user.id)
    end
    scope
  end

  def declaration_params
    params.expect(incident: %i[equipment_id description severity nature detected_at])
  end

  # Qualification et suivi : réservés aux administrateurs et responsables techniques.
  def qualification_params
    params.expect(incident: %i[description severity nature assigned_to_id
                               mandatory_declaration root_cause corrective_action])
  end

  # Champs modifiables pendant un changement de statut, selon le rôle.
  def transition_attributes
    permitted = if Current.user.admin? || Current.user.technical_manager?
                  %i[severity nature assigned_to_id mandatory_declaration root_cause corrective_action]
                else
                  %i[corrective_action]
                end
    params.fetch(:incident, {}).permit(*permitted)
  end
end
