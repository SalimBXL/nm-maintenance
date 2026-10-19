module Api
  module V1
    # Base de l'API : authentification par jeton personnel, droits Pundit
    # identiques à ceux de l'interface web, format d'erreur unique :
    #   { "error": { "code": "...", "message": "...", "details": ... } }
    class BaseController < ActionController::API
      include ActionController::HttpAuthentication::Token::ControllerMethods
      include Pundit::Authorization

      DEFAULT_PER_PAGE = 25
      MAX_PER_PAGE = 100

      before_action :authenticate!
      # Redéclaré après l'authentification pour que l'auteur soit connu.
      before_action :set_paper_trail_whodunnit
      after_action :verify_authorized
      after_action :verify_policy_scoped, only: :index

      rescue_from Pundit::NotAuthorizedError do
        render_error :forbidden, 'forbidden', "Vous n'avez pas le droit d'effectuer cette action."
      end
      rescue_from ActiveRecord::RecordNotFound do
        render_error :not_found, 'not_found', 'Ressource introuvable.'
      end
      rescue_from ActionController::ParameterMissing do |error|
        render_error :bad_request, 'bad_request', "Paramètre manquant : #{error.param}."
      end

      private

      def authenticate!
        token = authenticate_with_http_token { |value, _options| ApiToken.authenticate(value) }

        if token
          token.touch_last_used!
          Current.api_user = token.user
        else
          response.headers['WWW-Authenticate'] = 'Bearer realm="Maintenance"'
          render_error :unauthorized, 'unauthorized', 'Jeton manquant, invalide, expiré ou révoqué.'
        end
      end

      def pundit_user
        Current.user
      end

      def user_for_paper_trail
        Current.user&.id
      end

      def render_error(status, code, message, details = nil)
        error = { code: code, message: message }
        error[:details] = details if details
        render json: { error: error }, status: status
      end

      def render_validation_errors(record)
        render_error :unprocessable_entity, 'validation_failed', 'Données invalides.', record.errors.to_hash(true)
      end

      # Pagination : ?page=1&per_page=25 (100 au maximum).
      def paginate(scope)
        per_page = params[:per_page].to_i.clamp(1, MAX_PER_PAGE)
        per_page = DEFAULT_PER_PAGE unless params[:per_page].present?
        total = scope.count
        total_pages = [(total / per_page.to_f).ceil, 1].max
        page = params[:page].to_i.clamp(1, total_pages)

        records = scope.limit(per_page).offset((page - 1) * per_page)
        [records, { page: page, per_page: per_page, total: total, total_pages: total_pages }]
      end

      def render_collection(records, meta, &)
        render json: { data: records.map(&), meta: meta }
      end
    end
  end
end
