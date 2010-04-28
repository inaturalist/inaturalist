# Methods added to this helper will be available to all templates in the application.
# require 'recaptcha'
module ApplicationHelper  
  def gmap_include_tag(key = false)
    unless key
      '<script src="http://maps.google.com/maps?file=api&v=2&key=' +
      (Ym4r::GmPlugin::ApiKey.get)  + '" type="text/javascript"></script>'
    else 
      '<script src="http://maps.google.com/maps?file=api&v=2&key=' +
      (key) + '" type="text/javascript"></script>'
    end
  end
  
  def num2letterID(num)
    alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    alphabet[num,1]
  end
  
  def windowed_pagination_links(pagingEnum, options)
    link_to_current_page = options[:link_to_current_page]
    always_show_anchors = options[:always_show_anchors]
    padding = options[:window_size]

    current_page = pagingEnum.page
    html = ''

    #Calculate the window start and end pages 
    padding = padding < 0 ? 0 : padding
    first = pagingEnum.page_exists?(current_page  - padding) ? current_page - padding : 1
    last = pagingEnum.page_exists?(current_page + padding) ? current_page + padding : pagingEnum.last_page

    # Print start page if anchors are enabled
    html << yield(1) if always_show_anchors and not first == 1

    # Print window pages
    first.upto(last) do |page|
      (current_page == page && !link_to_current_page) ? html << page : html << yield(page)
    end

    # Print end page if anchors are enabled
    html << yield(pagingEnum.last_page) if always_show_anchors and not last == pagingEnum.last_page
    html
  end
  
  def compact_date(date)
    return 'the past' if date.nil?
    if date == Date.today 
      'Today'
    elsif date.year == Date.today.year 
      date.strftime("%b. %e") 
    else 
      date.strftime("%b. %e, %Y") 
    end 
  end
  
  def friend_button(user, potential_friend, html_options={})
    options = {
      :controller => 'users',
      :action => 'update',
      :id => current_user.id
    }
    html_options = {
      :class => 'link',
      :method => :put
    }.merge(html_options)
    case !user.friends.include?(potential_friend)
    when true
      if user != potential_friend
        button_to("Follow #{potential_friend.login}", options.merge({ :friend_id => potential_friend.id }), html_options)
      end
    when false # user is already a contact
        link_to("Stop following #{potential_friend.login}", 
          options.merge({ :remove_friend_id => potential_friend.id }), html_options)
    end
  end
  
  def char_wrap(text, len)
    return text if text.size < len
    text[0..len-1] + '<br/>' + char_wrap(text[len..-1], len)
  end
  
  # Generate an id for an object for us in views, e.g. an observation with id 
  # 4 would be "observation-4"
  def id_for(obj)
    "#{obj.class.name.underscore}-#{obj.id}"
  end

  def is_me?(user)
    logged_in? && (user == current_user)
  end
  
  def is_not_me?(user)
    logged_in? && (user != current_user)
  end
  
  def link_to_toggle(link_text, target_selector, options = {})
    options[:class] ||= ''
    options[:class] += ' togglelink'
    options[:rel] ||= target_selector
    link_to_function link_text, 
      "$('#{target_selector}').toggle(); $(this).toggleClass('open')", 
      options
  end
  
  # Generate a URL based on the current params hash, overriding existing values
  # withthe hash passed in.  To remove existing values, specify them with
  # :without => [:some, :keys]
  # Example: url_for_params(:taxon_id => 1, :without => :page)
  def url_for_params(options = {})
    new_params = params.clone
    if without = options.delete(:without)
      without = [without] unless without.is_a?(Array)
      without.map!(&:to_s)
      new_params.reject! {|k,v| without.include?(k) }
    end
    
    new_params.merge!(options) unless options.empty?
    
    url_for(new_params)
  end
  
  def link_to(*args)
    if args.size >= 2 && args[1].is_a?(Taxon) && args[1].unique_name? && 
        !(args[2] && args[2].is_a?(Hash) && args[2][:method])
      return super(args.first, url_for_taxon(args[1]), *args[2..-1])
    end
    super
  end
  
  def url_for_taxon(taxon)
    if taxon && taxon.unique_name?
      url_for(:controller => 'taxa', :action => taxon.unique_name.split.join('_'))
    else
      url_for(taxon)
    end
  end
  
  def modal_image(flickr_photo, params = {})
    size = params.delete(:size)
    size_method = size ? "#{size}_url" : 'square_url'
    # link_options = params.merge(:rel => flickr_photo_path(flickr_photo, :partial => 'photo'))
    link_options = params.merge(:rel => photo_path(flickr_photo, :partial => 'photo'))
    link_options[:class] ||= ''
    link_options[:class] += ' modal_image_link'
    link_to(
      image_tag(flickr_photo.send(size_method),
        :title => flickr_photo.attribution,
        :id => "flickr_photo_#{flickr_photo.id}",
        :class => 'image') + 
      image_tag('silk/magnifier.png', :class => 'zoom_icon'),
      flickr_photo.native_page_url,
      link_options
    )
  end
  
  def formatted_user_text(text)
    auto_link(markdown(simple_format(sanitize(text))))
  rescue BlueCloth::FormatError
    auto_link(simple_format(sanitize(text)))
  end
  
  def render_in_format(format, *args)
    old_format = @template.template_format
    @template.template_format = format
    html = render(*args)
    @template.template_format = old_format
    html
  end
end
