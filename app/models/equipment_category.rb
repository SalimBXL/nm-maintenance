class EquipmentCategory < ApplicationRecord
  include Archivable

  has_paper_trail

  has_many :equipment_models, foreign_key: :category_id, inverse_of: :category, dependent: :restrict_with_error

  normalizes :code_prefix, with: ->(v) { v.strip.upcase }

  # Préfixe de type du code interne : 2 à 8 caractères, sans tiret
  # (PET-CT devient PETCT, SPECT-CT devient SPECTCT).
  validates :name, presence: true, uniqueness: true
  validates :code_prefix, presence: true, uniqueness: true,
                          format: { with: /\A[A-Z0-9]{2,8}\z/, message: 'doit comporter 2 à 8 lettres ou chiffres, sans tiret' }
end
