# Gestion des utilisateurs réservée aux administrateurs ; chacun peut
# consulter sa propre fiche.
class UserPolicy < ApplicationPolicy
  def index? = admin?
  def show? = admin? || (signed_in? && record == user)
  def create? = admin?
  def update? = admin?

  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.none unless user.present? && user.active?

      user.admin? ? scope.all : scope.where(id: user.id)
    end
  end
end
