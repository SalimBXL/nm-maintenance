# Accès à la zone d'administration des référentiels (départements, locaux,
# catégories, fabricants, modèles) : administrateurs et responsables
# techniques. Les droits fins (qui peut créer ou modifier quoi) restent
# portés par la politique de chaque ressource.
#   authorize :admin, :access?
class AdminPolicy < ApplicationPolicy
  def access? = fleet_manager?
end
