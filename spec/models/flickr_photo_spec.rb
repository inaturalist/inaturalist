require File.dirname(__FILE__) + '/../spec_helper.rb'

describe FlickrPhoto, "creation" do
  fixtures :users, :flickr_identities
  
  before(:each) do
    @flickr = Net::Flickr.authorize(FLICKR_API_KEY, FLICKR_SHARED_SECRET)
    # grab Ken-ichi's photo of a Black Widow
    fp = @flickr.photos.get_info(2444432253)
    @cc_flickr_photo = FlickrPhoto.new_from_net_flickr(fp, 
      :user => User.find_by_login('ted'))
    
    # pic of a flower Ken-ichi has marked all rights reserved
    fp = @flickr.photos.get_info(2394365945)
    @noncc_flickr_photo = FlickrPhoto.new_from_net_flickr(fp,
      :user => User.find_by_login('ted'))
  end
  
  it "should not save if there is no assoc'd iNat user and the pic isn't CC" do
    @noncc_flickr_photo.user = nil
    @noncc_flickr_photo.valid?
    @noncc_flickr_photo.errors.on(:license).should be_blank
  end
  
  it "should make a valid FlickrPhoto from a Net::Flickr response" do
    fp = @flickr.photos.get_info(2444432253)
    FlickrPhoto.new_from_net_flickr(fp, :user => users(:quentin)).should be_valid
  end
  
  it "should make a valid FlickrPhoto from a flickraw response" do
    FlickRaw.api_key = FLICKR_API_KEY
    FlickRaw.shared_secret = FLICKR_SHARED_SECRET
    fp = flickr.photos.getInfo(:photo_id => 2444432253)
    FlickrPhoto.new_from_flickraw(fp, :user => users(:quentin)).should be_valid
  end
  
  it "should not be valid if the associated user didn't take the photo" do
    fp = @flickr.photos.get_info(469509092)
    photo_by_nate = FlickrPhoto.new_from_net_flickr(fp, 
      :user => users(:quentin))
    photo_by_nate.should_not be_valid
  end
end

describe FlickrPhoto, "to_observation" do
  fixtures :users, :flickr_identities
  
  before(:all) do
    load_test_taxa
    @flickr = Net::Flickr.authorize(FLICKR_API_KEY, FLICKR_SHARED_SECRET)
    # grab Ken-ichi's photo of an Anna's hummingbird
    @fp = @flickr.photos.get_info(3372373404)
  end
  
  before(:each) do
    @flickr_photo = FlickrPhoto.new_from_net_flickr(@fp, :user => users(:quentin))
  end
  
  it "should create a valid observation" do
    @flickr_photo.to_observation.should be_valid
  end
end
