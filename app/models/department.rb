class Department < ApplicationRecord
  include Archivable

  has_paper_trail

  belongs_to :parent, class_name: 'Department', optional: true
  belongs_to :manager, class_name: 'User', optional: true

  has_many :children, class_name: 'Department', foreign_key: :parent_id, inverse_of: :parent, dependent: :restrict_with_error
  has_many :locations, dependent: :restrict_with_error
  has_many :department_memberships, dependent: :restrict_with_error
  has_many :users, through: :department_memberships

  validates :name, presence: true, uniqueness: true
  validates :code, presence: true, uniqueness: true
  validate :single_level_for_now

  private

  # Décision : un seul niveau de départements pour l'instant. parent_id est
  # conservé (vide) ; supprimer cette validation suffira à activer plus tard
  # des sous-départements.
  def single_level_for_now
    errors.add(:parent_id, 'doit rester vide (un seul niveau de départements)') if parent_id.present?
  end
end
