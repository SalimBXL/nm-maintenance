# Jetons personnels d'API : chaque utilisateur gère les siens.
class ApiTokensController < ApplicationController
  # [jours, libellé, explication]
  DURATIONS = [
    [30, '30 jours', 'Test ou usage ponctuel.'],
    [90, '90 jours', 'Usage temporaire ou poste partagé.'],
    [365, '1 an', 'Outil ou poste personnel de confiance (valeur par défaut).']
  ].freeze

  after_action :verify_authorized
  after_action :verify_policy_scoped, only: :index

  helper_method :duration_options

  def index
    authorize ApiToken
    @tokens = policy_scope(ApiToken).order(created_at: :desc)
  end

  def new
    @token = ApiToken.new
    authorize @token
  end

  def create
    @token = ApiToken.new(name: params.dig(:api_token, :name), user: Current.user,
                          expires_at: duration_days.days.from_now)
    authorize @token

    if @token.save
      render :created
    else
      render :new, status: :unprocessable_content
    end
  end

  # Révocation : le jeton n'est pas supprimé, il cesse simplement de fonctionner.
  def destroy
    token = policy_scope(ApiToken).find(params[:id])
    authorize token
    token.revoke!
    redirect_to api_tokens_path, notice: "Le jeton « #{token.name} » a été révoqué."
  end

  private

  def duration_options
    DURATIONS.map { |days, label, help| [days, label, help] }
  end

  def duration_days
    requested = params.dig(:api_token, :duration).to_i
    DURATIONS.map(&:first).include?(requested) ? requested : ApiToken::DEFAULT_DURATION_DAYS
  end
end
