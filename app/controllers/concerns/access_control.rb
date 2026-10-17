# Contrôle d'accès avec Pundit. À inclure dans ApplicationController APRÈS
# `include Authentication` (la session doit être résolue avant les contrôles).
module AccessControl
  extend ActiveSupport::Concern
  include Pundit::Authorization

  included do
    rescue_from Pundit::NotAuthorizedError, with: :forbidden
  end

  private

  # Le générateur d'authentification de Rails 8 ne fournit pas current_user.
  def pundit_user
    Current.user
  end

  def forbidden
    respond_to do |format|
      format.html { redirect_back_or_to root_path, alert: "Vous n'avez pas le droit d'effectuer cette action." }
      format.json { render json: { error: 'forbidden' }, status: :forbidden }
      format.any { head :forbidden }
    end
  end
end
