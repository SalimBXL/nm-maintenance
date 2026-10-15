class EquipmentMove < ApplicationRecord
  has_paper_trail

  belongs_to :equipment
  belongs_to :from_location, class_name: "Location", optional: true
  belongs_to :to_location, class_name: "Location"
  belongs_to :user, optional: true   # auteur du déplacement

  validates :moved_at, presence: true
end
