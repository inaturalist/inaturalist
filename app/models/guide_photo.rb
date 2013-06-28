class GuidePhoto < ActiveRecord::Base
  attr_accessible :description, :guide_taxon_id, :photo_id, :title, :photo, :guide_taxon, :position
  belongs_to :guide_taxon, :inverse_of => :guide_photos
  belongs_to :photo, :inverse_of => :guide_photos
  validates :photo, :presence => true

  def url
    photo.try(:small_url)
  end

  def respond_to?(method, include_private = false)
    photo.respond_to?(method) || super
  end

  def method_missing(method, *args, &block)
    photo.respond_to?(method) ? photo.send(method, *args) : super
  end

  def as_json(options = {})
    options[:methods] ||= []
    options[:methods] += [:url, :square_url, :small_url, :medium_url, :large_url]
    options[:methods].uniq!
    super(options)
  end
end
