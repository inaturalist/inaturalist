module FlickrHelper
  def modal_image(flickr_photo, params = {})
    size = params.delete(:size)
    size_method = size ? "#{size}_url" : 'square_url'
    link_options = params.merge(
      :rel => flickr_photo_path(flickr_photo, :partial => 'photo'))
    link_options[:class] ||= ''
    link_options[:class] += ' modal_image_link'
    link_to(
      image_tag(flickr_photo.send(size_method),
        :title => flickr_photo.attribution,
        :id => "flickr_photo_#{flickr_photo.id}",
        :class => 'image') + 
      image_tag('silk/magnifier.png', :class => 'zoom_icon'),
      flickr_photo.flickr_page_url,
      link_options
    )
  end
end
