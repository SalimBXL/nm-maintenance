# Jetons d'API : chaque utilisateur actif gère ses propres jetons (création,
# consultation, révocation) et seulement les siens.
class ApiTokenPolicy < ApplicationPolicy
  def index? = signed_in?
  def create? = signed_in?
  def destroy? = signed_in? && record.user_id == user.id

  class Scope < ApplicationPolicy::Scope
    def resolve
      user.present? && user.active? ? scope.where(user_id: user.id) : scope.none
    end
  end
end
