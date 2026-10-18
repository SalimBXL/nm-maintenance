# Documents techniques.
#
# - Lecture et téléchargement : tout utilisateur actif.
# - Ajout, nouvelle version, modification, archivage : administrateur et
#   responsable technique.
# - Une nouvelle version ne se crée que sur la version la plus récente.
class DocumentPolicy < ApplicationPolicy
  def index? = signed_in?
  def show? = signed_in?
  def download? = signed_in?
  def create? = fleet_manager?
  def update? = fleet_manager?

  def new_version?
    fleet_manager? && record.current? && !record.archived?
  end

  def create_version? = new_version?

  class Scope < ApplicationPolicy::Scope
    def resolve
      user.present? && user.active? ? scope.all : scope.none
    end
  end
end
