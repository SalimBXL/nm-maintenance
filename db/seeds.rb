# Données de référence du jalon 1 (idempotent : peut être relancé sans doublon).

# Catégories d'équipements : nom => préfixe de type (8 caractères max, sans tiret)
{
  'PET-CT' => 'PETCT',
  'SPECT' => 'SPECT',
  'SPECT-CT' => 'SPECTCT',
  'Activimètre' => 'ACT',
  "Distributeur d'activité" => 'DIST',
  'Unidose' => 'UNID'
}.each do |name, prefix|
  EquipmentCategory.find_or_create_by!(code_prefix: prefix) { |category| category.name = name }
end

# Fabricants : nom => code court
{
  'GE' => 'GE',
  'Veenstra Instruments (gamme VIK)' => 'VIK',
  'Comecer' => 'COME',
  'Trasis' => 'TRAS'
}.each do |name, code|
  Manufacturer.find_or_create_by!(code: code) { |manufacturer| manufacturer.name = name }
end

# Premier administrateur, uniquement si ADMIN_EMAIL et ADMIN_PASSWORD sont
# fournis (aucun mot de passe par défaut dans le code). En développement, ils
# se placent dans le fichier .env (voir .env.example) ; sur un serveur, dans
# les variables d'environnement du service.
admin_email = ENV['ADMIN_EMAIL'].to_s.strip
admin_password = ENV['ADMIN_PASSWORD'].to_s

if admin_email.present? && admin_password.present?
  admin = User.find_or_create_by!(email_address: admin_email) do |user|
    user.name = ENV.fetch('ADMIN_NAME', 'Administrateur')
    user.password = admin_password
    user.role = :admin
  end

  if admin.previously_new_record?
    Rails.logger.info "Administrateur créé : #{admin.email_address}"
  else
    Rails.logger.info "Administrateur déjà présent : #{admin.email_address} (mot de passe inchangé)"
  end
  Rails.logger.warn 'Attention : le mot de passe compte moins de 12 caractères.' if admin_password.length < 12
else
  Rails.logger.info 'ADMIN_EMAIL ou ADMIN_PASSWORD absent : aucun administrateur créé.'
end
