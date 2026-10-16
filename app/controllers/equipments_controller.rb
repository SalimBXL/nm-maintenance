class EquipmentsController < ApplicationController
  PER_PAGE = 50

  before_action :set_equipment, only: %i[show edit update archive unarchive]
  after_action :verify_authorized
  after_action :verify_policy_scoped, only: :index

  def index
    authorize Equipment
    scope = filtered(policy_scope(Equipment))

    @total = scope.count
    @pages = [(@total / PER_PAGE.to_f).ceil, 1].max
    @page = params[:page].to_i.clamp(1, @pages)
    @equipments = scope
                  .includes(equipment_model: %i[manufacturer category], location: :department)
                  .order(:code)
                  .limit(PER_PAGE).offset((@page - 1) * PER_PAGE)

    @departments = Department.kept.order(:name)
    @categories = EquipmentCategory.kept.order(:name)
  end

  def show
    authorize @equipment
    @moves = @equipment.equipment_moves
                       .includes(:user, from_location: :department, to_location: :department)
                       .order(moved_at: :desc)
  end

  def new
    @equipment = Equipment.new(location_id: params[:location_id])
    authorize @equipment
    load_form_collections
  end

  def create
    @equipment = Equipment.new(equipment_params)
    authorize @equipment

    if @equipment.save
      redirect_to @equipment, notice: "Équipement créé avec le code #{@equipment.code}."
    else
      load_form_collections
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize @equipment
    load_form_collections
  end

  def update
    authorize @equipment

    if @equipment.update(equipment_params)
      redirect_to @equipment, notice: "Équipement mis à jour."
    else
      load_form_collections
      render :edit, status: :unprocessable_entity
    end
  end

  def archive
    authorize @equipment
    @equipment.archive!
    redirect_to @equipment, notice: "Équipement archivé."
  end

  def unarchive
    authorize @equipment, :archive?
    @equipment.unarchive!
    redirect_to @equipment, notice: "Équipement réactivé."
  end

  private

  def set_equipment
    @equipment = Equipment.includes(equipment_model: %i[manufacturer category], location: :department).find(params[:id])
  end

  # Le modèle ne se choisit qu'à la création : le code interne en dépend.
  def equipment_params
    permitted = %i[location_id serial_number criticality acquired_on commissioned_on warranty_ends_on notes]
    permitted += %i[equipment_model_id] if action_name == "create"
    permitted += %i[status decommissioned_on] if action_name == "update"
    params.require(:equipment).permit(*permitted)
  end

  def load_form_collections
    @models = EquipmentModel.kept.includes(:manufacturer, :category).sort_by { |model| [model.manufacturer.name, model.name] }
    @locations = Location.kept.includes(:department).sort_by { |location| [location.department.name, location.name] }
  end

  def filtered(scope)
    scope = scope.kept unless params[:archived] == "1"
    scope = scope.where(status: params[:status]) if Equipment.statuses.key?(params[:status])
    scope = scope.where(location_id: Location.where(department_id: params[:department_id])) if params[:department_id].present?
    scope = scope.where(location_id: params[:location_id]) if params[:location_id].present?
    scope = scope.where(equipment_model_id: EquipmentModel.where(category_id: params[:category_id])) if params[:category_id].present?
    scope = search(scope, params[:q]) if params[:q].present?
    scope
  end

  # Recherche sur le code, le numéro de série, le modèle et le fabricant.
  def search(scope, term)
    pattern = "%#{Equipment.sanitize_sql_like(term.to_s.strip)}%"
    by_model = EquipmentModel.joins(:manufacturer)
                             .where("equipment_models.name LIKE :p OR manufacturers.name LIKE :p", p: pattern)
                             .select(:id)

    scope.where("equipments.code LIKE :p OR equipments.serial_number LIKE :p", p: pattern)
         .or(scope.where(equipment_model_id: by_model))
  end
end
