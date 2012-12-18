#encoding: utf-8
class FacebookPhoto < Photo
  
  Photo.descendent_classes ||= []
  Photo.descendent_classes << self
  
  validates_presence_of :native_photo_id
  validate :owned_by_user?

  def owned_by_user?
    errors.add(:user, "doesn't own that photo") unless owned_by?(user)
  end

  def owned_by?(user)
    fbp_json = FacebookPhoto.get_api_response(self.native_photo_id, {:user=>user})
    return false unless user && fbp_json
    return false if user.facebook_identity.blank? || (fbp_json['from']['id'] != user.facebook_identity.provider_uid)
    true
  end

  # facebook doesn't provide a square image
  # so for now, just return the thumbnail image
  def square_url
    thumb_url
  end

  def repair
    fp = FacebookPhoto.get_api_response(native_photo_id, :user => user)
    errors = {}
    [:large_url, :medium_url, :small_url, :thumb_url].each_with_index do |img_size, i|
      send("#{img_size}=", fp['images'][i]['source'])
    end
    save
    [self, errors]
  end

  def self.repair(find_options = {})
    puts "[INFO #{Time.now}] starting FacebookPhoto.repair, options: #{find_options.inspect}"
    find_options[:include] ||= [:user, :taxon_photos, :observation_photos]
    find_options[:batch_size] ||= 100
    find_options[:sleep] ||= 10
    flickr = FlickRaw::Flickr.new
    updated = 0
    destroyed = 0
    invalids = 0
    start_time = Time.now
    FlickrPhoto.script_do_in_batches(find_options) do |p|
      r = Net::HTTP.get_response(URI.parse(p.medium_url))
      next unless r.code_type == Net::HTTPBadRequest
      repaired, errors = p.repair
      if errors.blank?
        updated += 1
      else
        puts "[DEBUG] #{errors.values.to_sentence}"
        if repaired.frozen?
          destroyed += 1 
          puts "[DEBUG] destroyed #{repaired}"
        end
        # if errors[:flickr_authorization_missing]
        #   invalids += 1
        #   puts "[DEBUG] authorization missing #{repaired}"
        # end
      end
    end
    puts "[INFO #{Time.now}] finished FacebookPhoto.repair, #{updated} updated, #{destroyed} destroyed, #{invalids} invalid, #{Time.now - start_time}s"
  end

  def self.get_api_response(native_photo_id, options = {})
    return nil unless (options[:user] && options[:user].facebook_api)
    options[:user].facebook_api.get_object(native_photo_id) || nil # api returns 'false' if photo not found
  end

  def self.new_from_api_response(api_response, options = {})
    fp = api_response
    return nil if fp.nil?
    # facebook api provides these sizes in an keyless array, in this order
    [:large_url, :medium_url, :small_url, :thumb_url].each_with_index{|img_size,i|
      options.update(img_size => fp['images'][i]['source'])
    }
    options.update(
      :native_photo_id => fp["id"],
      :square_url => nil, # facebook doesn't provide a square image
      :original_url => fp['source'],
      :native_page_url => fp["link"],
      :native_username => fp["from"]["name"],
      :native_realname => fp["from"]["name"],
      :license => nil
    )
    facebook_photo = FacebookPhoto.new(options)
    facebook_photo.api_response = fp
    facebook_photo
  end

  def to_observation
    fbp_json = self.api_response || FacebookPhoto.get_api_response(self.native_photo_id, :user => self.user)
    observation = Observation.new
    observation.user = self.user if self.user
    observation.observation_photos.build(:photo => self)
    observation.description = fbp_json["name"]
    #observation.observed_on_string = fp.taken.to_s(:long)
    #observation.munge_observed_on_with_chronic
    observation.time_zone = observation.user.time_zone if observation.user
    observation
  end

  # Get all the photos posted to the feed of the specified facebook group
  def self.fetch_from_fb_group(fb_group_id, user, options={})
    options[:limit] ||= 10
    options[:page] ||= 1
    limit = (options[:limit] || 10).to_i
    offset = ((options[:page] || 1).to_i - 1) * limit
    # this query gets the feed items from this group
    group_feed = user.facebook_api.fql_query("SELECT attachment 
                                              FROM stream 
                                              WHERE source_id=#{fb_group_id}
                                              LIMIT 5000")

    # filter out feed items that don't have a photo attached
    group_feed_photo_attachments = group_feed.delete_if{|f| f['attachment'].nil? || f['attachment']['fb_object_type']!='photo'}
    # pagination
    group_feed_photo_attachments = group_feed_photo_attachments[offset..(offset+limit-1)]
    group_feed_photo_ids = group_feed_photo_attachments.map{|a| a['attachment']['media'][0]['photo']['fbid']}
    fb_photos = user.facebook_api.get_objects(group_feed_photo_ids) # return hash like {"photo1_id"=>{photo1_data}, ...}
    return [] if fb_photos.is_a?(Array) and fb_photos.empty?
    fb_photos.values.map{|fp| FacebookPhoto.new_from_api_response(fp) }
  rescue Koala::Facebook::APIError => e
    Rails.logger.error "[ERROR #{Time.now}] #{e}"
    []
  end

  def self.add_comment(user, fb_photo_id, comment_text)
    return nil if user.facebook_api.nil?
    user.facebook_api.put_comment(fb_photo_id, comment_text)
  end

#  
#  # Try to extract known taxa from the tags of a flickr photo
#  def to_taxa(options = {})
#    self.api_response ||= FlickrPhoto.get_api_response(self.native_photo_id, :user => options[:user] || self.user)
#    taxa = if api_response.tags.blank?
#      []
#    else
#      # First try to find taxa matching taxonomic machine tags, then default 
#      # to all tags
#      tags = api_response.tags.values.map(&:raw)
#      machine_tags = tags.select{|t| t =~ /taxonomy\:/}
#      taxa = Taxon.tags_to_taxa(machine_tags) unless machine_tags.blank?
#      taxa ||= Taxon.tags_to_taxa(tags, options)
#      taxa
#    end
#    taxa.compact
#  end
  
end
