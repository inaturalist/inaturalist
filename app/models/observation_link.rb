class ObservationLink < ActiveRecord::Base
  belongs_to :observation
  before_save :set_href_name
  
  validates_uniqueness_of :href, :scope => :observation_id
  
  def to_s
    "<ObservationLink id: #{id}, observation_id: #{observation_id}, href_name: #{href_name}, href: #{href}>"
  end
  
  def set_href_name
    return true unless href_changed?
    return true if href.blank?
    self.href_name ||= URI.parse(href).host
    true
  end
end
