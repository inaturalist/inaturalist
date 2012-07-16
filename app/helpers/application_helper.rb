# Methods added to this helper will be available to all templates in the application.
# require 'recaptcha'
module ApplicationHelper
  include Ambidextrous
  
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
    if date.is_a?(Time)
      date = date.in_time_zone(current_user.time_zone) if current_user
      time = date
      date = date.to_date
    end
    today = if current_user
      Time.now.in_time_zone(current_user.time_zone).to_date
    else
      Date.today
    end
    if date == today
      time ? time.strftime("%I:%M %p").downcase.sub(/^0/, '')  : 'Today'
    elsif date.year == Date.today.year 
      date.strftime("%b %e") 
    else 
      date.strftime("%b %e, %Y") 
    end 
  end
  
  def friend_button(user, potential_friend, html_options = {})
    url_options = {
      :controller => 'users',
      :action => 'update',
      :id => current_user.id,
      :format => "json"
    }
    
    already_friends = if user.friends.loaded?
      user.friends.include?(potential_friend)
    else
      already_friends = user.friendships.find_by_friend_id(potential_friend.id)
    end
    
    unfriend_link = link_to_remote t(:stop_following_user, :user => " #{potential_friend.login}" ),
      :url => url_options.merge(:remove_friend_id => potential_friend.id), 
      :datatype => "json",
      :method => :put,
      :loading => 
        "$('##{dom_id(potential_friend, 'unfriend_link')}').fadeOut(function() { $('##{dom_id(potential_friend, 'friend_link')}').fadeIn() });",
      :html => html_options.merge(
        :id => dom_id(potential_friend, 'unfriend_link'),
        :style => already_friends ? "" : "display:none")
    friend_link = link_to_remote t(:follow_user, :user=> " #{potential_friend.login} "), 
      :url => url_options.merge(:friend_id => potential_friend.id), 
      :method => :put,
      :datatype => "json",
      :loading => 
        "$('##{dom_id(potential_friend, 'friend_link')}').fadeOut(function() { $('##{dom_id(potential_friend, 'unfriend_link')}').fadeIn() });",
      :html => html_options.merge(
        :id => dom_id(potential_friend, 'friend_link'),
        :style => (!already_friends && user != potential_friend) ? "" : "display:none")
    
    content_tag :span, friend_link + unfriend_link, :class => "friend_button"
  end
  
  def char_wrap(text, len)
    return text if text.size < len
    bits = text.split
    if bits.size == 1
      "#{text[0..len-1]}<br/>#{char_wrap(text[len..-1], len)}"
    else
      bits.map{|b| char_wrap(b, len)}.join(' ')
    end
  end
  
  # Generate an id for an object for us in views, e.g. an observation with id 
  # 4 would be "observation-4"
  def id_for(obj)
    "#{obj.class.name.underscore}-#{obj.id}"
  end

  def is_me?(user = @selected_user)
    logged_in? && (user.id == current_user.id)
  end
  
  def is_not_me?(user = @selected_user)
    !is_me?(user)
  end
  
  def is_admin?
    logged_in? && current_user.is_admin?
  end
  
  def is_curator?
    logged_in? && current_user.is_curator?
  end
  
  def curator_of?(project)
   return false unless logged_in?
   current_user.project_users.first(:conditions => {:project_id => project.id, :role => 'curator'})
  end
  
  def member_of?(project)
   return false unless logged_in?
   current_user.project_users.first(:conditions => {:project_id => project.id})
  end
  
  def link_to_toggle(link_text, target_selector, options = {})
    options[:class] ||= ''
    options[:class] += ' togglelink'
    options[:rel] ||= target_selector
    link_to_function link_text, 
      "$('#{target_selector}').toggle(); $(this).toggleClass('open')", 
      options
  end
  
  def link_to_toggle_menu(link_text, options = {}, &block)
    menu_id = options[:menu_id]
    menu_id ||= options[:id].parameterize if options[:id]
    menu_id ||= link_text.parameterize
    menu_id += rand(100).to_s
    wrapper_options = options.delete(:wrapper) || {}
    wrapper_options[:class] ||= ""
    wrapper_options[:class] += " toggle_menu"
    wrapper_options[:class] += " button_toggle_menu" if options[:class] && options[:class].split.include?("button")
    html = link_to_toggle(link_text, "##{menu_id}", options)
    html += content_tag(:div, capture(&block), :id => menu_id, :class => "menu", :style => "display: none")
    concat content_tag(:div, html, wrapper_options)
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
  
  def hidden_fields_for_params(options = {})
    new_params = request.query_parameters.clone
    if without = options.delete(:without)
      without = [without] unless without.is_a?(Array)
      without.map!(&:to_s)
      new_params.reject! {|k,v| without.include?(k) }
    end
    
    new_params.merge!(options) unless options.empty?
    
    html = ""
    new_params.each do |key, value|
      if value.is_a?(Array)
        value.each do |v|
          html += hidden_field_tag "#{key}[]", v
        end
      else
        html += hidden_field_tag key, value
      end
    end
    html
  end
  
  # def link_to(*args)
  #   if args.size >= 2 && args[1].is_a?(Taxon) && args[1].unique_name? && 
  #       !(args[2] && args[2].is_a?(Hash) && args[2][:method])
  #     return super(args.first, url_for_taxon(args[1]), *args[2..-1])
  #   end
  #   super
  # end
  
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
    img_url = flickr_photo.send(size_method)
    img_url ||= flickr_photo.send("small_url") if size_method != "square_url"
    link_options = params.merge(:rel => photo_path(flickr_photo, :partial => 'photo'))
    link_options[:class] ||= ''
    link_options[:class] += ' modal_image_link'
    link_to(
      image_tag(img_url,
        :title => flickr_photo.attribution,
        :id => "flickr_photo_#{flickr_photo.id}",
        :class => 'image') + 
      image_tag('silk/magnifier.png', :class => 'zoom_icon'),
      flickr_photo.native_page_url,
      link_options
    )
  end
  
  def formatted_user_text(text)
    return text if text.blank?
    
    # make sure attributes are quoted correctly
    text = text.gsub(/(\w+)=['"]([^'"]*?)['"]/, '\\1="\\2"')
    
    # Make sure P's don't get nested in P's
    text = text.gsub(/<\\?p>/, "\n\n")
    
    text = auto_link(markdown(simple_format(sanitize(text))))
    
    # Ensure all tags are closed
    Nokogiri::HTML::DocumentFragment.parse(text).to_s
  end
  
  def render_in_format(format, *args)
    old_format = @template.template_format
    @template.template_format = format
    html = render(*args)
    @template.template_format = old_format
    html
  end
  
  def in_format(format)
    old_format = @template.template_format
    @template.template_format = format
    yield
    @template.template_format = old_format
  end
  
  def taxonomic_taxon_list(taxa, options = {}, &block)
    taxa.each do |taxon, children|
      concat "<li class='#{options[:class]}'>"
      yield taxon
      unless children.blank?
        concat "<ul>"
        taxonomic_taxon_list(children, options, &block)
        concat "</ul>"
      end
      concat "</li>"
    end
  end
  
  def user_image(user, options = {})
    size = options.delete(:size)
    style = "vertical-align:middle; #{options[:style]}"
    url = if request
      "http://#{request.host}#{":#{request.port}" if request.port}#{user.icon.url(size || :mini)}"
    else
      "#{APP_CONFIG[:site_url]}#{user.icon.url(size || :mini)}"
    end
    image_tag(url, options.merge(:style => style))
  end
  
  def observation_image(observation, options = {})
    style = "vertical-align:middle; #{options[:style]}"
    url = observation_image_url(observation, options)
    url ||= iconic_taxon_image_url(observation.iconic_taxon_id)
    image_tag(url, options.merge(:style => style))
  end
  
  def image_and_content(image, options = {}, &block)
    image_size = options.delete(:image_size) || 48
    content = capture(&block)
    image_wrapper = content_tag(:div, image, :class => "image", :style => "width: #{image_size}px; position: absolute; left: 0; top: 0;")
    options[:class] = "image_and_content #{options[:class]}".strip
    options[:style] = "#{options[:style]}; padding-left: #{image_size.to_i + 10}px; position: relative; min-height: #{image_size}px;"
    concat content_tag(:div, image_wrapper + content, options)
  end
  
  # remove unecessary whitespace btwn divs
  def compact(&block)
    content = capture(&block)
    content.gsub!(/div\>[\n\s]+\<div/, 'div><div')
    concat content
  end
  
  def color_pluralize(num, singular)
    html = content_tag(:span, num, :class => "count")
    html += num == 1 ? " #{singular}" : " #{singular.pluralize}"
    html
  end
  
  def one_line_observation(o, options = {})
    skip = (options.delete(:skip) || []).map(&:to_sym)
    txt = ""
    txt += "#{o.user.login} observed " unless skip.include?(:user)
    unless skip.include?(:taxon)
      txt += if o.taxon
        render(:partial => 'shared/taxon', :locals => {
          :taxon => o.taxon,
          :include_article => true
        })
      else
        "something "
      end
      txt += " "
    end
    unless skip.include?(:observed_on)
      txt += if o.observed_on.blank?
        "in the past "
      else
        "on #{o.observed_on.to_s(:long)} "
      end
    end
    unless skip.include?(:place_guess)
      txt += if o.place_guess.blank?
        "somewhere in the Universe"
      else
        "in #{o.place_guess}"
      end
    end
    txt
  end
  
  def html_attributize(txt)
    strip_tags(txt).gsub('"', "'").gsub("\n", " ")
  end
  
  def separator
    content_tag :div, image_tag('logo-eee-15px.png'), :class => "column-separator"
  end
  
  def serial_id
    @__serial_id = @__serial_id.to_i + 1
    @__serial_id
  end
  
  def image_url(source, options = {})
    abs_path = image_path(source)
    unless abs_path =~ /\Ahttp/
     abs_path = [request.protocol, request.host_with_port, abs_path].join('')
    end
    abs_path
  end
  
  def truncate_with_more(text, options = {})
    more = options.delete(:more) || " ...more &darr;"
    less = options.delete(:less) || " less &uarr;"
    truncated = truncate(text, options)
    return truncated if text == truncated
    truncated = Nokogiri::HTML::DocumentFragment.parse(truncated)
    morelink = link_to_function(more, "$(this).parents('.truncated').hide().next('.untruncated').show()", 
      :class => "nobr ui")
    last_node = truncated.children.last || truncated
    last_node = last_node.parent if last_node.name == "a" || last_node.is_a?(Nokogiri::XML::Text)
    last_node.add_child(morelink)
    wrapper = content_tag(:div, truncated, :class => "truncated")
    
    lesslink = link_to_function(less, "$(this).parents('.untruncated').hide().prev('.truncated').show()", 
      :class => "nobr ui")
    untruncated = Nokogiri::HTML::DocumentFragment.parse(text)
    last_node = untruncated.children.last || untruncated
    last_node = last_node.parent if last_node.name == "a" || last_node.is_a?(Nokogiri::XML::Text)
    last_node.add_child(lesslink)
    untruncated = content_tag(:div, untruncated.to_s, :class => "untruncated", 
      :style => "display: none")
    wrapper + untruncated
  rescue RuntimeError => e
    raise e unless e.message =~ /error parsing fragment/
    HoptoadNotifier.notify(e, :request => request, :session => session)
    text
  end
  
  def native_url_for_photo(photo)
    return photo.native_page_url unless photo.native_page_url.blank?
    case photo.class.name
    when "FlickrPhoto"
      "http://flickr.com/photos/#{photo.native_username}/#{photo.native_photo_id}"
    when "LocalPhoto"
      url_for(photo.observations.first)
    else
      nil
    end
  end
  
  def helptip_for(id, options = {}, &block)
    tip_id = "#{id}_tip"
    html = content_tag(:span, '', :class => "#{options[:class]} #{tip_id}_target helptip", :rel => "##{tip_id}")
    html += content_tag(:div, capture(&block), :id => tip_id, :style => "display:none")
    concat html
  end
  
  def month_graph(counts, options = {})
    return '' if counts.blank?
    max = options[:max] || counts.values.max
    html = ''
    tag = options[:link] ? :a : :span
    tag_options = {:class => "bar spacer", :style => "height: 100%; width: 0"}
    html += content_tag(tag, " ", tag_options)
    %w(? J F M A M J J A S O N D).each_with_index do |name, month|
      count = counts[month.to_s] || 0
      tag_options = {:class => "bar month_#{month}", :style => "height: #{(count.to_f / max * 100).to_i}%"}
      if options[:link]
        tag_options[:href] = url_for(request.params.merge(:month => month))
      end
      html += content_tag(tag, tag_options) do
        content_tag(:span, count, :class => "count") +
        content_tag(:span, name, :class => "month")
      end
    end
    content_tag(:div, html, :class => 'monthgraph graph')
  end
  
  def catch_and_release(&block)
    concat capture(&block) if block_given?
  end
  
  def citation_for(record)
    return 'unknown' if record.blank?
    if record.is_a?(Source)
      h(record.citation || [record.title, record.in_text, record.url].join(', '))
    else
      render :partial => "#{record.class.to_s.underscore.pluralize}/citation", :object => record
    end
  rescue ActionView::MissingTemplate
    record.to_s.gsub(/[\<\>]*/, '')
  end
  
  def link_to_taxon(taxon, options = {})
    iconic_taxon = Taxon::ICONIC_TAXA_BY_ID[taxon.iconic_taxon_id]
    iconic_taxon_name = iconic_taxon.try(:name) || 'Unknown'
    url = taxon_path(taxon, options.delete(:url_params) || {})
    content_tag :span, :class => "taxon #{iconic_taxon_name} #{taxon.rank}" do
      link_to(iconic_taxon_image(taxon, :size => 15), url, options) + " " +
      link_to(default_taxon_name(taxon), url, options)
    end
  end
  
  def loading
    content_tag :span, (block_given? ? capture(&block) : 'Loading...'), :class => "loading status"
  end
  
  def setup_map_tag_attrs(taxon, options = {})
    taxon_range = options[:taxon_range]
    place = options[:place]
    map_tag_attrs = {"data-taxon-id" => taxon.id}
    if taxon_range
      map_tag_attrs["data-taxon-range-kml"] = root_url.gsub(/\/$/, "") + taxon_range.range.url
      map_tag_attrs["data-taxon-range-geojson"] = taxon_range_geom_url(taxon.id, :format => "geojson")
    end
    if place
      map_tag_attrs["data-latitude"] = place.latitude
      map_tag_attrs["data-longitude"] = place.longitude
      map_tag_attrs["data-bbox"] = place.bounding_box.join(',') if place.bounding_box
      map_tag_attrs["data-place-kml"] = place_geometry_url(place, :format => "kml") if @place_geometry || PlaceGeometry.without_geom.exists?(:place_id => place)
      map_tag_attrs["data-observations-json"] = observations_url(:taxon_id => taxon, :place_id => place, :format => "json")
      # map_tag_attrs["data-place-geojson"] = taxon_range_geom_url(@taxon.id, :format => "geojson")
    end
    map_tag_attrs
  end
  
  def google_static_map_for_observation_url(o, options = {})
    url_for_options = {
      :host => 'maps.google.com',
      :controller => 'maps/api/staticmap',
      :center => "#{o.latitude},#{o.longitude}",
      :zoom => o.map_scale || 7,
      :size => '200x200',
      :sensor => 'false',
      :markers => "color:0x#{iconic_taxon_color(o.iconic_taxon_id)}|#{o.latitude},#{o.longitude}",
      :key => Ym4r::GmPlugin::ApiKey.get
    }.merge(options)
    url_for(url_for_options)
  end
  
  def rights(record, options = {})
    separator = options[:separator] || "<br/>"
    if record.is_a? Observation
      user_name = record.user.name
      user_name = record.user.login if user_name.blank?
      s = "&copy; #{user_name}"
      if record.license.blank?
        s += "#{separator}all rights reserved"
      else
        s += separator
        s += content_tag(:span) do
          c = if options[:skip_image]
            ""
          else
            link_to(image_tag("#{record.license}_small.png"), url_for_license(record.license)) + " "
          end
          c + link_to(t(:some_rights_reserved), url_for_license(record.license))
        end
      end
    elsif record.is_a? Photo
      if record.user.blank?
        s = record.attribution
      else
        user_name = record.user.name
        user_name = record.user.login if user_name.blank?
        s = if record.copyrighted? || record.creative_commons?
          "&copy; #{user_name}"
        else
          "no known copy restrictions"
        end

        if record.copyrighted?
          s += "#{separator}all rights reserved"
        elsif record.creative_commons?
          s += separator
          code = Photo.license_code_for_number(record.license)
          url = url_for_license(code)
          s += content_tag(:span) do
            c = if options[:skip_image]
              ""
            else
              link_to(image_tag("#{code}_small.png"), url) + " "
            end
            c + link_to(t(:some_rights_reserved), url)
          end
        end
      end
    end
    content_tag :span, s, :class => "rights verticalmiddle"
  end
  
  def url_for_license(code)
    "http://creativecommons.org/licenses/#{code[/CC\-(.+)/, 1].downcase}/3.0/"
  end
  
  def update_image_for(update, options = {})
    options[:style] = "vertical-align:middle; #{options[:style]}"
    resource = if @update_cache && @update_cache[update.resource_type.underscore.pluralize.to_sym]
      @update_cache[update.resource_type.underscore.pluralize.to_sym][update.resource_id]
    end
    resource ||= update.resource
    case update.resource_type
    when "User"
      image_tag("#{root_url}#{resource.icon.url(:thumb)}", options.merge(:alt => "#{resource.login} icon"))
    when "Observation"
      observation_image(resource, options.merge(:size => "square"))
    when "ListedTaxon"
      image_tag("#{root_url}images/checklist-icon-color-32px.png", options)
    when "Post"
      image_tag("#{root_url}#{resource.user.icon.url(:thumb)}", options)
    when "Place"
      image_tag("#{root_url}images/icon-maps.png", options)
    else
      image_tag("#{root_url}images/logo-grey-32px.png", options)
    end
  end
  
  def update_tagline_for(update, options = {})
    resource = if @update_cache && @update_cache[update.resource_type.underscore.pluralize.to_sym]
      @update_cache[update.resource_type.underscore.pluralize.to_sym][update.resource_id]
    end
    resource ||= update.resource
    case update.resource_type
    when "User"
      if options[:count].to_i == 1
        "#{options[:skip_links] ? resource.login : link_to(resource.login, url_for_resource_with_host(resource))} added an observation"
      else
        "#{options[:skip_links] ? resource.login : link_to(resource.login, url_for_resource_with_host(resource))} added #{options[:count]} observations"
      end
    when "Observation", "ListedTaxon"
      class_name = update.resource.class.to_s.underscore.humanize.downcase
      notifier = if @update_cache && @update_cache[update.notifier_type.underscore.pluralize.to_sym]
        @update_cache[update.notifier_type.underscore.pluralize.to_sym][update.notifier_id]
      end
      notifier ||= update.notifier
      if notifier.respond_to?(:user)
        notifier_user = if @update_cache && @update_cache[:users]
          @update_cache[:users][notifier.user_id]
        end
        notifier_user = notifier.user
      end
      s = if update.notification == "activity" && notifier_user
        notifier_class_name = notifier.class.to_s.underscore.humanize.downcase
        "#{options[:skip_links] ? notifier_user.login : link_to(notifier_user.login, person_url(notifier_user))} " + 
        "added #{notifier_class_name =~ /^[aeiou]/i ? 'an' : 'a'} <strong>#{notifier_class_name}</strong> to "
      else
        s = "New activity on "
      end
      s += "#{class_name =~ /^[aeiou]/i ? 'an' : 'a'} #{options[:skip_links] ? class_name : link_to(class_name, url_for_resource_with_host(resource))}"
      s += " by #{you_or_login(update.resource_owner)}" if update.resource_owner
      s
    when "Post"
      "New activity on \"#{options[:skip_links] ? resource.title : link_to(resource.title, url_for_resource_with_host(resource))}\" by #{update.resource_owner.login}"
    when "Place"
      "New observations from #{options[:skip_links] ? resource.display_name : link_to(resource.display_name, url_for_resource_with_host(resource))}"
    else
      "update"
    end
  end
  
  def url_for_resource_with_host(resource)
    "#{APP_CONFIG[:site_url]}#{url_for(resource)}"
  end
  
  def commas_and(list)
    return list.first.to_s if list.size == 1
    return list.join(' and ') if list.size == 2
    "#{list[0..-2].join(', ')}, and #{list.last}"
  end
  
  def update_cached(record, association)
    if @update_cache && @update_cache[association.to_s.pluralize.to_sym]
      cached = @update_cache[association.to_s.pluralize.to_sym][record.send("#{association}_id")]
    end
    cached ||= record.send(association)
  end
  
end
