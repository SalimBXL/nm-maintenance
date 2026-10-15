# Lecture pour tout utilisateur actif ; création et modification réservées
# aux administrateurs.
class DepartmentPolicy < FleetPolicy
  def create? = admin?
  def update? = admin?
end
