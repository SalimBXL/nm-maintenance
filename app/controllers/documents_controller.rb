class DocumentsController < ApplicationController
  PER_PAGE = 50

  before_action :set_document, only: %i[show edit update download new_version create_version archive unarchive]
  after_action :verify_authorized
  after_action :verify_policy_scoped, only: :index

  def index
    authorize Document
    scope = filtered(policy_scope(Document))

    @total = scope.count
    @pages = [(@total / PER_PAGE.to_f).ceil, 1].max
    @page = params[:page].to_i.clamp(1, @pages)
    @documents = scope
                 .includes(:uploaded_by, :equipment, equipment_model: :manufacturer)
                 .order(:document_type, :title, :version_number)
                 .limit(PER_PAGE).offset((@page - 1) * PER_PAGE)
  end

  def show
    authorize @document
    @versions = @document.chain
  end

  def new
    @document = Document.new(equipment_id: params[:equipment_id], equipment_model_id: params[:equipment_model_id])
    authorize @document
    load_form_data
  end

  def edit
    authorize @document
  end

  def create
    @document = Document.new(create_params)
    apply_target_kind(@document)
    @document.uploaded_by = Current.user
    authorize @document

    if @document.save
      redirect_to @document, notice: 'Le document a été ajouté.'
    else
      load_form_data
      render :new, status: :unprocessable_content
    end
  end

  def update
    authorize @document

    if @document.update(update_params)
      redirect_to @document, notice: 'Le document a été mis à jour.'
    else
      render :edit, status: :unprocessable_content
    end
  end

  def download
    authorize @document, :download?
    file = @document.file
    send_data file.download, filename: file.filename.to_s, type: file.content_type, disposition: 'attachment'
  end

  def new_version
    authorize @document
    @new_document = next_version_of(@document)
  end

  def create_version
    authorize @document
    @new_document = next_version_of(@document)
    @new_document.assign_attributes(version_params)
    @new_document.uploaded_by = Current.user

    if @new_document.save
      redirect_to @new_document, notice: "La version #{@new_document.version_number} a été ajoutée."
    else
      render :new_version, status: :unprocessable_content
    end
  end

  def archive
    authorize @document
    @document.archive!
    redirect_to @document, notice: 'Le document a été archivé.'
  end

  def unarchive
    authorize @document, :archive?
    @document.unarchive!
    redirect_to @document, notice: 'Le document a été réactivé.'
  end

  private

  def set_document
    @document = Document.includes(:equipment, equipment_model: :manufacturer).find(params[:id])
  end

  def load_form_data
    @equipments = Equipment.kept.includes(:equipment_model, location: :department).order(:code)
    @models = EquipmentModel.kept.includes(:manufacturer, :category).sort_by { |model| [model.manufacturer.name, model.name] }
    @target_kind = params.dig(:document, :target_kind).presence || (@document.equipment_model_id ? 'model' : 'equipment')
  end

  # La nouvelle version reprend le rattachement, le type et le titre de la précédente.
  def next_version_of(previous)
    Document.new(
      supersedes: previous,
      equipment_id: previous.equipment_id,
      equipment_model_id: previous.equipment_model_id,
      document_type: previous.document_type,
      title: previous.title
    )
  end

  # Le formulaire propose un équipement ou un modèle : le choix « rattaché à »
  # décide lequel des deux est retenu.
  def apply_target_kind(document)
    case params.dig(:document, :target_kind)
    when 'equipment' then document.equipment_model_id = nil
    when 'model' then document.equipment_id = nil
    end
  end

  def filtered(scope)
    scope = scope.current unless params[:all_versions] == '1'
    scope = scope.kept unless params[:archived] == '1'
    scope = scope.where(document_type: params[:document_type]) if Document.document_types.key?(params[:document_type])
    scope = scope.where(equipment_id: params[:equipment_id]) if params[:equipment_id].present?
    scope = scope.where(equipment_model_id: params[:equipment_model_id]) if params[:equipment_model_id].present?
    scope = filter_by_validity(scope, params[:validity])
    params[:q].present? ? search(scope, params[:q]) : scope
  end

  def filter_by_validity(scope, validity)
    today = Time.zone.today
    case validity
    when 'expired' then scope.where(valid_until: ...today)
    when 'expiring' then scope.where(valid_until: today..(today + Document::EXPIRING_DAYS))
    else scope
    end
  end

  # Recherche sur le titre, les notes, le code de l'équipement, le modèle et le fabricant.
  def search(scope, term)
    pattern = "%#{Document.sanitize_sql_like(term.to_s.strip)}%"
    equipment_ids = Equipment.where('equipments.code LIKE ?', pattern).select(:id)
    model_ids = EquipmentModel.joins(:manufacturer)
                              .where('equipment_models.name LIKE :p OR manufacturers.name LIKE :p', p: pattern)
                              .select(:id)

    scope.where('documents.title LIKE :p OR documents.notes LIKE :p', p: pattern)
         .or(scope.where(equipment_id: equipment_ids))
         .or(scope.where(equipment_model_id: model_ids))
  end

  def create_params
    params.require(:document).permit(:title, :document_type, :equipment_id, :equipment_model_id,
                                     :version_label, :valid_until, :notes, :file)
  end

  def version_params
    params.require(:document).permit(:title, :version_label, :valid_until, :notes, :file)
  end

  def update_params
    params.require(:document).permit(:title, :document_type, :version_label, :valid_until, :notes)
  end
end
