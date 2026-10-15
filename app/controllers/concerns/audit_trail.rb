# Renseigne l'auteur (whodunnit) des versions PaperTrail avec l'utilisateur
# connecté. À inclure dans ApplicationController APRÈS `include Authentication`
# pour que la session soit résolue avant que l'auteur soit lu.
module AuditTrail
  extend ActiveSupport::Concern

  included do
    # Redéclaré ici pour passer après require_authentication.
    before_action :set_paper_trail_whodunnit
  end

  private

  def user_for_paper_trail
    Current.user&.id
  end
end
