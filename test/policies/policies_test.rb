require 'test_helper'

class PoliciesTest < ActiveSupport::TestCase
  FLEET_POLICIES = [EquipmentPolicy, LocationPolicy, EquipmentCategoryPolicy, EquipmentModelPolicy,
                    ManufacturerPolicy].freeze
  MANAGER_ROLES = %i[admin technical_manager].freeze
  OTHER_ROLES = %i[technician reporter].freeze

  def user_with(role, valid_until: nil)
    User.new(name: role.to_s, email_address: "#{role}@example.com", password: 'secret', role: role,
             valid_until: valid_until)
  end

  # --- Parc et référentiels : lecture pour tous, écriture pour les gestionnaires du parc

  test 'tout utilisateur actif peut consulter le parc et les référentiels' do
    FLEET_POLICIES.each do |policy|
      (MANAGER_ROLES + OTHER_ROLES).each do |role|
        subject = policy.new(user_with(role), nil)
        assert subject.index?, "#{policy} index? pour #{role}"
        assert subject.show?, "#{policy} show? pour #{role}"
      end
    end
  end

  test 'administrateur et responsable technique gèrent le parc' do
    FLEET_POLICIES.each do |policy|
      MANAGER_ROLES.each do |role|
        subject = policy.new(user_with(role), nil)
        assert subject.create?, "#{policy} create? pour #{role}"
        assert subject.update?, "#{policy} update? pour #{role}"
        assert subject.archive?, "#{policy} archive? pour #{role}"
      end
    end
  end

  test 'technicien et déclarant ne modifient pas le parc' do
    FLEET_POLICIES.each do |policy|
      OTHER_ROLES.each do |role|
        subject = policy.new(user_with(role), nil)
        assert_not subject.create?, "#{policy} create? pour #{role}"
        assert_not subject.update?, "#{policy} update? pour #{role}"
        assert_not subject.archive?, "#{policy} archive? pour #{role}"
      end
    end
  end

  test 'personne ne peut supprimer physiquement' do
    (FLEET_POLICIES + [DepartmentPolicy, UserPolicy]).each do |policy|
      (MANAGER_ROLES + OTHER_ROLES).each do |role|
        assert_not policy.new(user_with(role), nil).destroy?, "#{policy} destroy? pour #{role}"
      end
    end
  end

  # --- Départements : écriture réservée aux administrateurs

  test "seul l'administrateur crée et modifie les départements" do
    assert DepartmentPolicy.new(user_with(:admin), nil).create?
    assert DepartmentPolicy.new(user_with(:admin), nil).update?

    (%i[technical_manager] + OTHER_ROLES).each do |role|
      assert DepartmentPolicy.new(user_with(role), nil).show?
      assert_not DepartmentPolicy.new(user_with(role), nil).create?, "create? pour #{role}"
      assert_not DepartmentPolicy.new(user_with(role), nil).update?, "update? pour #{role}"
    end
  end

  # --- Utilisateurs

  test "seul l'administrateur gère les utilisateurs" do
    admin = user_with(:admin)
    other = user_with(:technician)

    assert UserPolicy.new(admin, other).index?
    assert UserPolicy.new(admin, other).update?
    assert UserPolicy.new(admin, other).show?

    assert_not UserPolicy.new(other, admin).index?
    assert_not UserPolicy.new(other, admin).update?
    assert_not UserPolicy.new(other, admin).show?
  end

  test 'chacun peut consulter sa propre fiche' do
    technician = user_with(:technician)

    assert UserPolicy.new(technician, technician).show?
  end

  # --- Journal d'audit

  test "l'audit est lisible par l'administrateur et le responsable technique" do
    MANAGER_ROLES.each do |role|
      assert AuditLogPolicy.new(user_with(role), nil).index?, "index? pour #{role}"
    end

    OTHER_ROLES.each do |role|
      assert_not AuditLogPolicy.new(user_with(role), nil).index?, "index? pour #{role}"
    end
  end

  # --- Utilisateurs non connectés ou non actifs

  test 'sans utilisateur, tout est refusé' do
    (FLEET_POLICIES + [DepartmentPolicy, UserPolicy, AuditLogPolicy]).each do |policy|
      subject = policy.new(nil, nil)
      assert_not subject.index?, "#{policy} index?"
      assert_not subject.show?, "#{policy} show?"
      assert_not subject.create?, "#{policy} create?"
      assert_not subject.update?, "#{policy} update?"
    end
  end

  test "un administrateur non actif n'a aucun droit" do
    expired = user_with(:admin, valid_until: Time.zone.today - 1)

    (FLEET_POLICIES + [DepartmentPolicy, UserPolicy, AuditLogPolicy]).each do |policy|
      subject = policy.new(expired, nil)
      assert_not subject.index?, "#{policy} index?"
      assert_not subject.create?, "#{policy} create?"
      assert_not subject.update?, "#{policy} update?"
    end
  end

  # --- Portées (scopes)

  test 'la portée du parc est vide sans utilisateur actif' do
    assert_equal 0, EquipmentPolicy::Scope.new(nil, Equipment).resolve.count
    assert_equal 0,
                 EquipmentPolicy::Scope.new(user_with(:admin, valid_until: Time.zone.today - 1),
                                            Equipment).resolve.count
  end

  test 'la portée des utilisateurs se limite à soi-même hors administrateur' do
    admin = User.create!(name: 'Admin', email_address: 'admin@example.com', password: 'secret', role: :admin)
    technician = User.create!(name: 'Tech', email_address: 'tech@example.com', password: 'secret', role: :technician)

    assert_includes UserPolicy::Scope.new(admin, User).resolve, technician
    assert_equal [technician], UserPolicy::Scope.new(technician, User).resolve.to_a
  end
end
