#encoding: utf-8
class GuidePhoto < ApplicationRecord
  belongs_to :guide_taxon, :inverse_of => :guide_photos
  belongs_to :photo, :inverse_of => :guide_photos
  has_one :guide, :through => :guide_taxon
  validates :photo, :presence => true
  validates_length_of :description, :maximum => 256, :allow_blank => true
  after_destroy :destroy_orphan_photo
  after_save {|r| r.guide.expire_caches(:check_ngz => true) if r.guide}
  after_destroy {|r| r.guide.expire_caches(:check_ngz => true) if r.guide}

  accepts_nested_attributes_for :photo

  acts_as_taggable

  def to_s
    "<GuidePhoto #{id}>"
  end

  def url
    photo.try(:small_url)
  end

  def method_missing(method, *args, &block)
    photo.respond_to?(method) ? photo.send(method, *args) : super
  end

  def serializable_hash(opts = nil)
    options = opts ? opts.clone : { }
    options[:methods] ||= []
    options[:methods] += [:url, :square_url, :small_url, :medium_url, :large_url]
    options[:methods].uniq!
    super(options)
  end

  def destroy_orphan_photo
    Photo.delay(:priority => INTEGRITY_PRIORITY).destroy_orphans(photo_id)
    true
  end

  def photo_attributes=(attributes)
    return if photo # no updating
    if attributes[:id].blank? && attributes[:thumb_url].blank? && !attributes[:native_photo_id].blank?
      klass = Object.const_get(attributes[:type])
      # attempt to lookup photo with native_photo_id
      # look within the custom subclass
      self.photo = if existing = Photo.where(
        native_photo_id: attributes[:native_photo_id],
        type: attributes[:type],
        subtype: nil
      ).first
        existing
      # look at LocalPhotos whose subtype is the custom subclass
      elsif attributes[:type] != "LocalPhoto" && existing = Photo.where(
        native_photo_id: attributes[:native_photo_id],
        type: "LocalPhoto",
        subtype: attributes[:type]
      ).first
        existing
      else
        r = klass.get_api_response(attributes[:native_photo_id])
        klass.new_from_api_response(r)
      end
      unless self.photo.is_a?( LocalPhoto )
        # turn all remote photos into LocalPhotos
        self.photo = Photo.local_photo_from_remote_photo( self.photo )
      end
    else
      self.photo = LocalPhoto.new({:user_id => guide.user_id}.merge(attributes.symbolize_keys))
    end
  rescue => e
    Rails.logger.debug "[DEBUG] Error assigning GuidePhoto photo attributes: #{e}"
    assign_nested_attributes_for_one_to_one_association(:photo, attributes)
  end

  def reusable?(options = {})
    user_id = if options[:user]
      options[:user].is_a?(User) ? options[:user].id : options[:user]
    end
    return true if user_id && guide.guide_users.map(&:user_id).include?(user_id)
    return true if photo.user_id == user_id
    !photo.license.blank? && photo.license != 0
  end
end
