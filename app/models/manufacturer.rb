class Manufacturer < ApplicationRecord
  include Archivable

  has_paper_trail

  has_many :equipment_models, dependent: :restrict_with_error

  normalizes :code, with: ->(v) { v.strip.upcase }

  # Code court utilisé dans le code interne des équipements (GE, VIK, COME, TRAS).
  validates :name, presence: true, uniqueness: true
  validates :code, presence: true, uniqueness: true,
                   format: { with: /\A[A-Z]{2,5}\z/, message: 'doit comporter 2 à 5 lettres' }
end
