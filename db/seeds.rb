# Données de référence du jalon 1 (idempotent : peut être relancé sans doublon).

# Catégories d'équipements : nom => préfixe de type (8 caractères max, sans tiret)
{
  "PET-CT" => "PETCT",
  "SPECT" => "SPECT",
  "SPECT-CT" => "SPECTCT",
  "Activimètre" => "ACT",
  "Distributeur d'activité" => "DIST",
  "Unidose" => "UNID"
}.each do |name, prefix|
  EquipmentCategory.find_or_create_by!(code_prefix: prefix) { |category| category.name = name }
end

# Fabricants : nom => code court
{
  "GE" => "GE",
  "Veenstra Instruments (gamme VIK)" => "VIK",
  "Comecer" => "COME",
  "Trasis" => "TRAS"
}.each do |name, code|
  Manufacturer.find_or_create_by!(code: code) { |manufacturer| manufacturer.name = name }
end

# Premier administrateur, uniquement si les variables d'environnement sont
# fournies (aucun mot de passe par défaut dans le code) :
#   ADMIN_EMAIL=... ADMIN_PASSWORD=... bin/rails db:seed
if ENV["ADMIN_EMAIL"].present? && ENV["ADMIN_PASSWORD"].present?
  User.find_or_create_by!(email_address: ENV["ADMIN_EMAIL"]) do |user|
    user.name = ENV.fetch("ADMIN_NAME", "Administrateur")
    user.password = ENV["ADMIN_PASSWORD"]
    user.role = :admin
  end
end
