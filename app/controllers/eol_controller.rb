class EolController < ApplicationController
  before_filter :return_here, :only => [:options]
  before_filter :login_required

    
  # Return an HTML fragment containing checkbox inputs for EOL photos.
  # Params:
  #   q:        query string
  def photo_fields
    # Try to look up a photo id
    @photos = []
    #taxon_id = 49257#
    taxon_id = params[:taxon_id]
    @taxon = Taxon.find_by_id(taxon_id)
    begin
       @photos << EolPhoto.new_from_taxon_name(@taxon.name)
    rescue
      @photos = []
    end
    
    render :partial => 'photos/photo_list_form', :locals => {
      :photos => @photos, 
      :index => params[:index],
      :local_photos => false }
  end
    
end

#p = FlickrPhoto.new(:user_id =>5, :native_photo_id => "71369389", :square_url => "http://farm1.static.flickr.com/35/71369389_69d29db0bf_s.jpg", :thumb_url=> "http://farm1.static.flickr.com/35/71369389_69d29db0bf_t.jpg", :small_url => "http://farm1.static.flickr.com/35/71369389_69d29db0bf_m.jpg", :medium_url => "http://farm1.static.flickr.com/35/71369389_69d29db0bf.jpg", :large_url => "http://farm1.static.flickr.com/35/71369389_69d29db0bf_b.jpg", :original_url => "http://farm1.static.flickr.com/35/71369389_69d29db0bf_o.jpg", :native_page_url => "http://flickr.com/photos/45285223@N00/71369389", :type => "FlickrPhoto")
#p = EolPhoto.new(:user_id =>5, :native_photo_id => "71369389", :square_url => "http://farm1.static.flickr.com/35/71369389_69d29db0bf_s.jpg", :thumb_url=> "http://farm1.static.flickr.com/35/71369389_69d29db0bf_t.jpg", :small_url => "http://farm1.static.flickr.com/35/71369389_69d29db0bf_m.jpg", :medium_url => "http://farm1.static.flickr.com/35/71369389_69d29db0bf.jpg", :large_url => "http://farm1.static.flickr.com/35/71369389_69d29db0bf_b.jpg", :original_url => "http://farm1.static.flickr.com/35/71369389_69d29db0bf_o.jpg", :native_page_url => "http://flickr.com/photos/45285223@N00/71369389")
#p=EolPhoto.new_from_api_response("Pomacanthus paru")
#p = EolPhoto.new(:user_id => nil, :native_photo_id => "5f7865f94bd6cb3221ee57f671c2baf8", :square_url => nil, :thumb_url=> "http://farm1.static.flickr.com/35/71369389_69d29db0bf_t.jpg", :small_url => nil, :medium_url => nil, :large_url => "http://farm1.static.flickr.com/35/71369389_69d29db0bf_b.jpg", :original_url => "http://farm1.static.flickr.com/35/71369389_69d29db0bf_o.jpg", :native_page_url => "http://flickr.com/photos/45285223@N00/71369389", :native_username => "Geoff Gallice", :native_realname => "Geoff Gallice", :license => 0)
#<%= photo.id ? modal_image(photo, :size => :square, :class => photo_pos_class) : link_to(image_tag(photo.square_url), photo.native_page_url, :class => photo_pos_class) %>

