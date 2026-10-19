# Contexte de la requête en cours. `session` : connexion web ; `api_user` :
# utilisateur identifié par un jeton d'API. `Current.user` fonctionne dans les
# deux cas.
class Current < ActiveSupport::CurrentAttributes
  attribute :session
  attribute :api_user

  def user
    api_user || session&.user
  end
end
