class FlickrIdentity < ActiveRecord::Base
  belongs_to :user
    
  named_scope :auto_import_is_on, :conditions => { :auto_import => true }
  named_scope :not_yet_imported, :conditions => ["auto_imported_at IS ?", nil]
  named_scope :last_import_more_than_one_hour_ago, :conditions => ["auto_imported_at > ?", 1.hour.ago]
  
  # This method is to be run by a cron job via script/runner
  # it is not intended to be called by the app in any other context!!!!
  def self.import_observations_from_flickr
    flickr_users = self.auto_import_is_on.find(:all)
  end
  
  def self.initial_import_from_flickr
    flickr_users = self.auto_import_is_on.not_yet_imported.find(:all)
    flickr = get_net_flickr
    flickr_users.each do |flickr_user|
      results = flickr.photos.search({'user_id'  => flickr_user.flickr_user_id,
                                      'per_page' => 500, # max it out on initial import
                                      'tags'     => 'inaturalist'})
      unless results.size == 0
        results.each do |photo|
          # map the photo to an observation
          obs = Observation.new({:user_id       => flickr_user.user_id,
                                 :species_guess => photo.title,
                                 :description   => photo.description})
          obs.photos << FlickrPhoto.new(:native_photo_id => photo.id,
            :square_url => photo.source_url(:square))
          obs.save
        end
      end
      flickr_user.auto_imported_at = Time.now
      flickr_user.save
    end
  end
  
  # probably should put this in a lib/ file and include it
  private
  def self.get_net_flickr
    Net::Flickr.authorize(FLICKR_API_KEY, FLICKR_SHARED_SECRET)
  end

end
