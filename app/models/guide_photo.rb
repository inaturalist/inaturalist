#encoding: utf-8
class GuidePhoto < ActiveRecord::Base
  attr_accessible :description, :guide_taxon_id, :photo_id, :title, :photo, :guide_taxon, :position
  belongs_to :guide_taxon, :inverse_of => :guide_photos
  belongs_to :photo, :inverse_of => :guide_photos
  has_one :guide, :through => :guide_taxon
  validates :photo, :presence => true
  after_destroy :destroy_orphan_photo
  after_save {|r| r.guide.expire_caches(:check_ngz => true)}
  after_destroy {|r| r.guide.expire_caches(:check_ngz => true)}

  def to_s
    "<GuidePhoto #{id}>"
  end

  def url
    photo.try(:small_url)
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

  def destroy_orphan_photo
    Photo.delay.destroy_orphans(photo_id)
    true
  end
end
