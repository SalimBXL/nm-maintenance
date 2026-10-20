class Location < ApplicationRecord
  include Archivable

  has_paper_trail

  belongs_to :department
  belongs_to :referent, class_name: 'User', optional: true # référent du local (ex. SPECT ou PET)

  has_many :equipments, dependent: :restrict_with_error

  validates :name, presence: true
  validates :code, presence: true, uniqueness: { scope: :department_id }
end
