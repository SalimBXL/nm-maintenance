module AdminHelper
  ADMIN_TABS = [
    ["Départements", :admin_departments_path, "departments"],
    ["Locaux", :admin_locations_path, "locations"],
    ["Catégories", :admin_equipment_categories_path, "equipment_categories"],
    ["Fabricants", :admin_manufacturers_path, "manufacturers"],
    ["Modèles", :admin_equipment_models_path, "equipment_models"]
  ].freeze

  def admin_tabs
    tabs = ADMIN_TABS.dup
    tabs << ["Utilisateurs", :admin_users_path, "users"] if policy(User).index?

    tabs.map do |label, path_helper, controller|
      [label, public_send(path_helper), controller_name == controller]
    end
  end

  # Valeur affichée (non modifiable) d'un champ « create_only » en édition.
  def readonly_value(record, field)
    value = record.public_send(field[:name])
    return value unless field[:type] == :select

    (@collections || {}).fetch(field[:collection], []).find { |_label, id| id == value }&.first || value
  end

  def role_label(role)
    t("enums.user.role.#{role}")
  end

  # Validité du compte : date de fin facultative ; non actif si elle est passée.
  def validity_label(user)
    if user.valid_until.nil?
      "Sans limite"
    elsif user.active?
      "Jusqu'au #{l(user.valid_until)}"
    else
      "Expiré le #{l(user.valid_until)}"
    end
  end
end
