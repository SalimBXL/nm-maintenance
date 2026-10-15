# Politique de base : tout est refusé par défaut. Chaque ressource ouvre
# explicitement ce qu'elle autorise.
class ApplicationPolicy
  attr_reader :user, :record

  def initialize(user, record)
    @user = user
    @record = record
  end

  def index? = false
  def show? = false
  def create? = false
  def new? = create?
  def update? = false
  def edit? = update?
  def archive? = update?

  # Pas de suppression physique des données : on archive.
  def destroy? = false

  class Scope
    def initialize(user, scope)
      @user = user
      @scope = scope
    end

    def resolve
      raise NotImplementedError, "#{self.class} doit définir resolve"
    end

    private

    attr_reader :user, :scope
  end

  private

  # Un utilisateur non actif (date de fin de validité dépassée) n'a aucun droit.
  def signed_in?
    user.present? && user.active?
  end

  def admin?
    signed_in? && user.admin?
  end

  # Administrateur ou responsable technique : gèrent le parc.
  def fleet_manager?
    signed_in? && (user.admin? || user.technical_manager?)
  end
end
