class DepartmentMembership < ApplicationRecord
  has_paper_trail

  belongs_to :user
  belongs_to :department

  validates :user_id, uniqueness: { scope: :department_id }
end
