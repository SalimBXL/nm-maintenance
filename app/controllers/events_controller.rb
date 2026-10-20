class EventsController < ApplicationController
  PER_PAGE = 50
  STATUS_ORDER = Arel.sql("CASE events.status WHEN 'in_progress' THEN 0 WHEN 'planned' THEN 1 ELSE 2 END")
  NO_DATE_LAST = Arel.sql('events.scheduled_on IS NULL')

  before_action :set_event, only: %i[show edit update transition]
  after_action :verify_authorized
  after_action :verify_policy_scoped, only: :index

  def index
    authorize Event
    scope = filtered(policy_scope(Event))

    @total = scope.count
    @pages = [(@total / PER_PAGE.to_f).ceil, 1].max
    @page = params[:page].to_i.clamp(1, @pages)
    @events = scope
              .includes({ equipment: { location: :department } }, :performed_by)
              .order(STATUS_ORDER, NO_DATE_LAST, :scheduled_on, id: :desc)
              .limit(PER_PAGE).offset((@page - 1) * PER_PAGE)

    @departments = Department.kept.order(:name)
  end

  def show
    authorize @event
    @allowed_targets = policy(@event).allowed_targets
  end

  def new
    incident = Incident.find_by(id: params[:incident_id])
    @event = Event.new(
      incident: incident,
      equipment: incident&.equipment || Equipment.kept.find_by(id: params[:equipment_id]),
      event_type: incident ? :corrective : :preventive
    )
    authorize @event
    load_form_data
  end

  def edit
    authorize @event
    load_form_data
  end

  def create
    @event = Event.new(create_params)
    @event.equipment ||= @event.incident&.equipment
    @event.performed_by = Current.user if technician?
    authorize @event

    if @event.save
      redirect_to @event, notice: "L'intervention a été enregistrée."
    else
      load_form_data
      render :new, status: :unprocessable_content
    end
  end

  def update
    authorize @event

    if @event.update(update_params)
      redirect_to @event, notice: "L'intervention a été mise à jour."
    else
      load_form_data
      render :edit, status: :unprocessable_content
    end
  end

  def transition
    authorize @event, :transition?
    target = params[:to].to_s

    unless policy(@event).allowed_targets.include?(target)
      redirect_to @event, alert: "Ce changement de statut n'est pas permis."
      return
    end

    if @event.transition(target, user: Current.user, attributes: transition_attributes)
      redirect_to @event, notice: "Statut mis à jour : #{t("enums.event.status.#{@event.status}").downcase}."
    else
      @allowed_targets = policy(@event).allowed_targets
      render :show, status: :unprocessable_content
    end
  end

  private

  def set_event
    @event = Event.includes(equipment: { location: :department }).find(params.expect(:id))
  end

  def manager?
    Current.user.admin? || Current.user.technical_manager?
  end

  def technician?
    !manager? && Current.user.technician?
  end

  def load_form_data
    @assignees = User.active.where(role: %w[technician technical_manager admin]).order(:name)
    @equipments = Equipment.kept.includes(:equipment_model, location: :department).order(:code) if manager?
    return unless manager? && @event.equipment_id

    @incidents = Incident.unclosed.where(equipment_id: @event.equipment_id).order(:id)
  end

  def filtered(scope)
    status = params[:status].to_s
    scope = scope.open_ones if status.blank?
    scope = scope.where(status: status) if Event.statuses.key?(status)
    scope = scope.where(event_type: params[:event_type]) if Event.event_types.key?(params[:event_type])
    scope = scope.where(equipment_id: params[:equipment_id]) if params[:equipment_id].present?
    scope = scope.where(incident_id: params[:incident_id]) if params[:incident_id].present?
    if params[:department_id].present?
      scope = scope.where(equipment_id: Equipment.where(location_id: Location.where(department_id: params[:department_id])))
    end
    scope = scope.where(performed_by_id: Current.user.id) if params[:mine] == '1'
    scope
  end

  def create_params
    permitted = if manager?
                  %i[equipment_id incident_id event_type title scheduled_on performed_by_id contractor]
                else
                  %i[incident_id event_type title scheduled_on contractor]
                end
    params.expect(event: [*permitted])
  end

  def update_params
    permitted = if manager?
                  %i[event_type title scheduled_on started_at ended_at performed_by_id contractor incident_id
                     report downtime_minutes cost_euros]
                else
                  %i[title scheduled_on started_at ended_at contractor report downtime_minutes cost_euros]
                end
    params.expect(event: [*permitted])
  end

  # Champs saisissables lors d'un changement de statut (début, fin, rapport…).
  def transition_attributes
    params.fetch(:event, {}).permit(:started_at, :ended_at, :report, :downtime_minutes, :cost_euros, :contractor)
  end
end
