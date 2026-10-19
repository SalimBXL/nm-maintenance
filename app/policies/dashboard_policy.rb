# Tableau de bord : tout utilisateur actif (les données affichées sont celles
# que chacun peut déjà consulter dans les listes).
#   authorize :dashboard, :show?
class DashboardPolicy < ApplicationPolicy
  def show? = signed_in?
end
