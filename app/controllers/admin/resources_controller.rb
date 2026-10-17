# Base commune des écrans d'administration des référentiels. Chaque
# contrôleur fils décrit sa ressource : resource_class, resource_title,
# fields (formulaire), columns (liste) et, si besoin, collections,
# includes et archive_blocker. Les vues sont partagées (admin/resources).
module Admin
  class ResourcesController < ApplicationController
    before_action { authorize :admin, :access? }
    before_action :set_record, only: %i[edit update archive unarchive]
    after_action :verify_authorized
    after_action :verify_policy_scoped, only: :index

    helper_method :resource_class, :resource_title, :fields, :columns

    def index
      authorize resource_class
      scope = policy_scope(resource_class)
      scope = scope.kept unless params[:archived] == '1'
      scope = scope.includes(*includes) if includes.any?
      @records = scope.order(default_order)
    end

    def new
      @record = resource_class.new
      authorize @record
      load_collections
    end

    def edit
      authorize @record
      load_collections
    end

    def create
      @record = resource_class.new(record_params)
      authorize @record

      if @record.save
        redirect_to index_path, notice: "« #{@record.name} » a été créé."
      else
        load_collections
        render :new, status: :unprocessable_content
      end
    end

    def update
      authorize @record

      if @record.update(record_params)
        redirect_to index_path, notice: "« #{@record.name} » a été mis à jour."
      else
        load_collections
        render :edit, status: :unprocessable_content
      end
    end

    def archive
      authorize @record

      if (reason = archive_blocker(@record))
        redirect_to index_path, alert: reason
      else
        @record.archive!
        redirect_to index_path, notice: "« #{@record.name} » a été archivé."
      end
    end

    def unarchive
      authorize @record, :archive?
      @record.unarchive!
      redirect_to index_path(archived: '1'), notice: "« #{@record.name} » a été réactivé."
    end

    private

    # --- À définir dans chaque contrôleur fils

    def resource_class = raise(NotImplementedError)
    def resource_title = raise(NotImplementedError)
    def fields = raise(NotImplementedError)
    def columns = raise(NotImplementedError)

    # Options des listes déroulantes : { nom: [[libellé, id], ...] }
    def collections = {}

    def includes = []

    def default_order = :name

    # Message d'erreur si l'archivage est impossible, sinon nil.
    def archive_blocker(_record) = nil

    # --- Commun

    def set_record
      @record = resource_class.find(params[:id])
    end

    def load_collections
      @collections = collections
    end

    def index_path(options = {})
      polymorphic_path([:admin, resource_class], options)
    end

    # Les champs « create_only » ne se choisissent qu'à la création : ils
    # entrent dans la composition des codes ou lient les enregistrements.
    def record_params
      names = fields.reject { |field| field[:create_only] && action_name != 'create' }.map { |field| field[:name] }
      params.require(resource_class.model_name.param_key).permit(*names)
    end
  end
end
