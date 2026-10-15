class User < ApplicationRecord
  has_paper_trail skip: [:password_digest]
  has_secure_password

  has_many :sessions, dependent: :destroy
  has_many :department_memberships, dependent: :destroy
  has_many :departments, through: :department_memberships

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  enum :role, {
    reporter: "reporter",                  # déclarant
    technician: "technician",              # technicien
    technical_manager: "technical_manager", # responsable technique
    admin: "admin"                         # administrateur
  }, default: :reporter, validate: true

  validates :name, presence: true
  validates :email_address, presence: true, uniqueness: true

  # Un utilisateur est non actif si sa date de fin de validité (optionnelle)
  # est antérieure à la date du jour. Pas de champ « actif » stocké : l'état
  # se calcule à partir de la date. Le compte reste actif le jour même de la
  # date de fin. « La date du jour » suit le fuseau horaire configuré
  # (config.time_zone), pas l'UTC.
  scope :active, -> { where("users.valid_until IS NULL OR users.valid_until >= ?", Time.zone.today) }
  scope :inactive, -> { where("users.valid_until < ?", Time.zone.today) }

  def active?
    valid_until.nil? || valid_until >= Time.zone.today
  end

  # Un utilisateur non actif ne peut plus se connecter.
  def self.authenticate_by(attributes)
    user = super
    user if user&.active?
  end
end
