class ContactPointGroupMembership < ApplicationRecord
  has_paper_trail

  belongs_to :contact_point_group
  belongs_to :contact_point

  validate :same_organization

  private

  def same_organization
    return unless contact_point_group && contact_point
    return if contact_point_group.organization_id == contact_point.organization_id
    errors.add(:contact_point, :must_belong_to_same_organization)
  end
end
