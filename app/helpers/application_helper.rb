#encoding: utf-8
# Methods added to this helper will be available to all templates in the application.
# require 'recaptcha'
module ApplicationHelper
  include Ambidextrous
  
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
    
    unfriend_link = link_to t(:stop_following_user, :user => potential_friend.login), 
      url_options.merge(:remove_friend_id => potential_friend.id), 
      html_options.merge(
        :remote => true,
        :datatype => "json",
        :method => :put,
        :id => dom_id(potential_friend, 'unfriend_link'),
        :class => "unfriend_link",
        :style => already_friends ? "" : "display:none"
      )
    friend_link = link_to t(:follow_user, :user=> potential_friend.login), 
      url_options.merge(:friend_id => potential_friend.id), 
      html_options.merge(
        :remote => true,
        :method => :put,
        :datatype => "json",
        :id => dom_id(potential_friend, 'friend_link'),
        :class => "friend_link",
        :style => (!already_friends && user != potential_friend) ? "" : "display:none"
      )
    
    content_tag :span, (friend_link + unfriend_link).html_safe, :class => "friend_button"
  end
  
  def char_wrap(text, len)
    return text if text.size < len
    "#{text[0..len-1]}<br/>#{char_wrap(text[len..-1], len)}".html_safe
  end
  
  # Generate an id for an object for us in views, e.g. an observation with id 
  # 4 would be "observation-4"
  def id_for(obj)
    "#{obj.class.name.underscore}-#{obj.id}"
  end

  def is_me?(user = @selected_user, options = {})
    if respond_to?(:user_signed_in?)
      logged_in? && (user.try(:id) == current_user.id)
    else
      options[:current_user] && (user.try(:id) == options[:current_user].id)
    end
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
   current_user.project_users.where(:project_id => project).where("role IN ('manager', 'curator')").exists?
  end
  
  def member_of?(project)
   return false unless logged_in?
   current_user.project_users.where(project_id: project.id).first
  end

  # TODO: This is removed in Rails 4, but we use it hundrends of times so
  # I recurrected it. Ideally we'd update the places that use this method
  def link_to_function(name, function, html_options = {})
    onclick = "#{"#{html_options[:onclick]}; " if html_options[:onclick]}#{function}; return false;"
    href = html_options[:href] || "#"
    content_tag(:a, name, html_options.merge(href: href, onclick: onclick))
  end

  def link_to_toggle(link_text, target_selector, options = {})
    options[:class] ||= ''
    options[:class] += ' togglelink'
    options[:rel] ||= target_selector
    link_to link_text, "#",
      options.merge(:onclick => "$('#{target_selector}').toggle(); $(this).toggleClass('open')")
  end

  def link_to_toggle_box(txt, options = {}, &block)
    options[:class] ||= ''
    options[:class] += ' togglelink'
    link = link_to_function(txt, "$(this).siblings('.togglebox').toggle(); $(this).toggleClass('open')", options)
    hidden = content_tag(:div, capture(&block), :style => "display:none", :class => "togglebox")
    content_tag :div, link + hidden
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

  def link_to_dialog(title, options = {}, &block)
    options[:title] ||= title
    options[:modal] ||= true
    id = title.gsub(/\W/, '').underscore
    dialog = content_tag(:div, capture(&block), :class => "dialog", :style => "display:none", :id => "#{id}_dialog")
    link_options = options.delete(:link) || {}
    link = link_to_function(title, "$('##{id}_dialog').dialog(#{options.to_json})", link_options)
    dialog + link
  end
  
  # Generate a URL based on the current params hash, overriding existing values
  # with the hash passed in.  To remove existing values, specify them with
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
    html.html_safe
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
  
  def modal_image(photo, options = {})
    size = options[:size]
    img_url ||= photo.best_url(size)
    link_options = options.merge("data-photo-path" => photo_path(photo, :partial => 'photo'))
    link_options[:class] = "#{link_options[:class]} modal_image_link #{size}".strip
    link_to(
      image_tag(img_url,
        :title => photo.attribution,
        :id => "photo_#{photo.id}",
        :class => "image #{size}") + 
      image_tag('silk/magnifier.png', :class => 'zoom_icon'),
      photo.native_page_url,
      link_options
    )
  end
  
  def formatted_user_text(text, options = {})
    return text if text.blank?
    
    # make sure attributes are quoted correctly
    text = text.gsub(/(<.+?)(\w+)=['"]([^'"]*?)['"](>)/, '\\1\\2="\\3"\\4')
    
    unless options[:skip_simple_format]
      # Make sure P's don't get nested in P's
      text = text.gsub(/<\\?p>/, "\n\n")

      # blockquotes should always start with a P
      text = text.gsub(/blockquote(.*?)>\s*/, "blockquote\\1>\n\n")
    end
    text = sanitize(text, options)
    text = compact(text, :all_tags => true) if options[:compact]
    text = simple_format(text, {}, :sanitize => false) unless options[:skip_simple_format]
    text = auto_link(text.html_safe, :sanitize => false).html_safe
    # scrub to fix any encoding issues
    text = text.scrub.gsub(/<a /, '<a rel="nofollow" ')
    # Ensure all tags are closed
    Nokogiri::HTML::DocumentFragment.parse(text).to_s.html_safe
  end
  
  def markdown(text)
    BlueCloth::new(text).to_html
  end
  
  def render_in_format(format, *args)
    old_formats = formats
    self.formats = [format]
    html = render(*args)
    self.formats = old_formats
    html
  end
  
  def in_format(format)
    old_formats = formats
    self.formats = [format]
    yield
    self.formats = old_formats
  end
  
  def taxonomic_taxon_list(taxa, options = {}, &block)
    taxa.each do |taxon, children|
      concat "<li class='#{options[:class]}'>".html_safe
      yield taxon, children
      unless children.blank?
        concat "<ul class='#{options[:ul_class]}'>".html_safe
        taxonomic_taxon_list(children, options, &block)
        concat "</ul>".html_safe
      end
      concat "</li>".html_safe
    end
  end
  
  def user_image(user, options = {})
    user ||= User.new
    size = options.delete(:size)
    style = "vertical-align:middle; #{options[:style]}"
    options[:alt] ||= user.login
    options[:title] ||= user.login
    url = if defined? root_url
      uri_join(root_url, user.icon.url(size || :mini))
    else
      url_join(CONFIG.site_url, user.icon.url(size || :mini))
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
    image_wrapper = content_tag(:div, image, :class => "image", :style => "width: #{image_size}px; position: absolute; left: 0; top: 0; text-align:center;")
    options[:class] = "image_and_content #{options[:class]}".strip
    options[:style] = "#{options[:style]}; padding-left: #{image_size.to_i + 10}px; position: relative;"
    options[:style] += "min-height: #{image_size}px;" unless options[:square] == false
    content_tag(:div, image_wrapper + content, options)
  end
  
  # remove unecessary whitespace btwn divs
  def compact(*args, &block)
    content = args[0] if args[0].is_a?(String)
    options = args.last.is_a?(Hash) ? args.last : {}
    content = capture(&block) if block_given?
    content ||= ""
    if options[:all_tags]
      content.gsub!(/\>[\n\s]+\</m, '><')
    else
      content.gsub!(/div\>[\n\s]+\<div/, 'div><div')
    end
    block_given? ? concat(content.html_safe) : content.html_safe
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
        t(:something)
      end
      txt += " "
    end
    unless skip.include?(:observed_on)
      txt += if o.observed_on.blank?
        t(:in_the_past).downcase
      else
        "#{t(:on_day, :default => "on")} #{o.observed_on.strftime("%d %b %Y")} "
      end
    end
    unless skip.include?(:place_guess)
      txt += if o.place_guess.blank?
        t(:somewhere_on_earth).downcase
      else
        "#{t(:in, :default => "in")} #{o.place_guess}"
      end
    end
    txt
  end
  
  def html_attributize(txt)
    return txt if txt.blank?
    strip_tags(txt).gsub('"', "'").gsub("\n", " ")
  end
  
  def separator
    content_tag :div, image_tag(image_url('logo-eee-15px.png')), :class => "column-separator"
  end
  
  def serial_id
    @__serial_id = @__serial_id.to_i + 1
    @__serial_id
  end
  
  def image_url(source, options = {})
    abs_path = image_path(source).to_s
    unless abs_path =~ /\Ahttp/
     abs_path = uri_join(options[:base_url] || @site.try(:url) || root_url, abs_path).to_s
    end
    abs_path
  rescue Sprockets::Helpers::RailsHelper::AssetPaths::AssetNotPrecompiledError
    nil
  end
  
  def truncate_with_more(text, options = {})
    return text if text.blank?
    more = options.delete(:more) || " ...#{t(:more).downcase} &darr;".html_safe
    less = options.delete(:less) || " #{t(:less).downcase} &uarr;".html_safe
    options[:omission] ||= ""
    options[:separator] ||= " "
    truncated = truncate(text, options.merge(escape: false))
    return truncated.html_safe if text == truncated
    truncated = Nokogiri::HTML::DocumentFragment.parse(truncated)
    morelink = link_to_function(more, "$(this).parents('.truncated').hide().next('.untruncated').show()", 
      :class => "nobr ui")
    last_node = truncated.children.last || truncated
    last_node = last_node.parent if last_node.name == "a" || last_node.is_a?(Nokogiri::XML::Text)
    last_node.add_child(Nokogiri::HTML::DocumentFragment.parse(morelink, 'UTF-8'))
    wrapper = content_tag(:div, truncated.to_s.html_safe, :class => "truncated")
    
    lesslink = link_to_function(less, "$(this).parents('.untruncated').hide().prev('.truncated').show()", 
      :class => "nobr ui")
    untruncated = Nokogiri::HTML::DocumentFragment.parse(text)
    last_node = untruncated.children.last || untruncated
    last_node = last_node.parent if last_node.name == "a" || last_node.is_a?(Nokogiri::XML::Text)
    last_node.add_child(Nokogiri::HTML::DocumentFragment.parse(lesslink, 'UTF-8'))
    untruncated = content_tag(:div, untruncated.to_s.html_safe, :class => "untruncated", 
      :style => "display: none")
    wrapper + untruncated
  rescue RuntimeError => e
    raise e unless e.message =~ /error parsing fragment/
    Airbrake.notify(e, :request => request, :session => session)
    text.html_safe
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

  def flickr_buddyicon(iconfarm,iconserver,nsid)
    if iconserver.to_i > 0
      return "http://farm#{iconfarm}.staticflickr.com/#{iconserver}/buddyicons/#{nsid}.jpg"
    else
      return "http://www.flickr.com/images/buddyicon.gif"
    end
  end
  
  def helptip_for(id, options = {}, &block)
    tip_id = "#{id}_tip"
    html = content_tag(:span, '', :class => "#{options[:class]} #{tip_id}_target helptip", :rel => "##{tip_id}")
    html += content_tag(:div, capture(&block), :id => tip_id, :style => "display:none")
    concat html
  end

  def helptip(text, options = {}, &block)
    tip_id = "tip_#{serial_id}"
    html = content_tag(:span, text, :class => "#{options[:class]} #{tip_id}_target helptip helptiptext", :rel => "##{tip_id}")
    html += content_tag(:div, capture(&block), :id => tip_id, :style => "display:none")
    html
  end
  
  def month_graph(counts, options = {})
    return '' if counts.blank?
    max = options[:max] || counts.values.max
    html = ''
    tag = options[:link] ? :a : :span
    tag_options = {:class => "bar spacer", :style => "height: 100%; width: 0"}
    html += content_tag(tag, " ", tag_options)
    Date::MONTHNAMES.each_with_index do |month_name, month_index|
      count = counts[month_index.to_s] || 0
      month_name = month_name || "?"
      tag_options = {:class => "bar month_#{month_index}", :style => "height: #{(count.to_f / max * 100).to_i}%"}
      if options[:link]
        url_params = options[:link].is_a?(Hash) ? options[:link] : request.params
        tag_options[:href] = url_for(url_params.merge(:month => month_index))
      end
      html += content_tag(tag, tag_options) do
        content_tag(:span, count, :class => "count") +
        content_tag(:span, t(month_name.downcase, :default => month_name)[0], :class => "month")
      end
    end
    content_tag(:div, html.html_safe, :class => 'monthgraph graph')
  end
  
  def catch_and_release(&block)
    concat capture(&block) if block_given?
  end
  
  def citation_for(record)
    return t(:unknown) if record.blank?
    if record.is_a?(Source)
      html = record.citation || [record.title, record.in_text, record.url].join(', ')
      html += " (" + link_to(t(:link), record.url) + ")" unless record.url.blank?
      if record.editable_by?(current_user)
        html += " " + link_to(t(:edit_source), edit_source_path(record), :class => "nobr small").html_safe
      end
      html.html_safe
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
    taxon_name = options[:sciname] ? taxon.name : default_taxon_name(taxon)
    if options[:sciname]
      options[:class] = "#{options[:class]} sciname".strip
    end
    content_tag :span, :class => "taxon #{iconic_taxon_name} #{taxon.rank}" do
      link_to(iconic_taxon_image(taxon, :size => 15), url, options) + " " +
      link_to(taxon_name, url, options)
    end
  end

  def link_to(*args, &block)
    unless block_given?
      body, url, options = args
      url_candidate = begin
        url_for(url)
      rescue ArgumentError => e
        raise e unless e.message =~ /invalid byte sequence/
        if url.is_a?(String)
          url_for(url_for.encode('UTF-8'))
        else
          new_pieces = {}
          url.each {|k,v| new_pieces[k] = v.encode('UTF-8')}
          url_for(new_pieces)
        end
      end
      if url_candidate =~ /\?/
        options ||= {}
        options[:rel] ||= "nofollow" unless options[:rel].to_s =~ /nofollow/
      end
      super(body, url, options)
    else
      super
    end
  end
  
  def loading(content = nil, options = {})
    content ||= "Loading..."
    options[:class] = "#{options[:class]} loading status"
    content_tag :span, (block_given? ? capture(&block) : content), options
  end
  
  def setup_map_tag_attrs(options = {})
    map_tag_attrs = {
      "taxon" => options[:taxon] ? options[:taxon].
        to_json(only: [ :id, :name ],
          include: { common_name: { only: [ :name ] } }
        ) : nil,
      "latitude" => options[:latitude],
      "longitude" => options[:longitude],
      "map-type" => options[:map_type],
      "zoom-level" => options[:zoom_level],
      "show-range" => options[:show_range] ? "true" : nil,
      "place" => options[:place] ? options[:place].
        to_json(only: [ :id, :name ]) : nil,
      "min-x" => options[:min_x],
      "min-y" => options[:min_y],
      "max-x" => options[:max_x],
      "max-y" => options[:max_y],
      "flag-letters" => options[:flag_letters] ? "true" : nil,
      "windshaft-project-id" => options[:windshaft_project_id],
      "windshaft-user-id" => options[:windshaft_user_id],
      "map-type-control" => options[:map_type_control],
      "observations" => observations_for_map_tag_attrs(options),
      "place-layer-label" => I18n.t("maps.overlays.place_boundary"),
      "taxon_range_layer_label" => I18n.t("maps.overlays.taxon_range"),
      "all_layer_label" => I18n.t("maps.overlays.all_observations"),
      "all_layer_description" => I18n.t("maps.overlays.every_publicly_visible_observation"),
      "featured_layer_label" => I18n.t("maps.overlays.featured_observations")
    }
    if options[:taxon]
      map_tag_attrs["taxon-range-layer-description"] = options[:taxon].to_styled_s
    end
    # Adjust the map bounds based on the content being displayed
    unless options[:zoom_level] && !map_tag_attrs["min-x"]
      if options[:taxon] && (!options[:focus] || options[:focus] == :taxon)
        append_bounds_to_map_tag_attrs(map_tag_attrs, options[:taxon])
      end
      if options[:taxon] && options[:show_range] && (!options[:focus] || options[:focus] == :range)
        append_bounds_to_map_tag_attrs(map_tag_attrs, options[:taxon].taxon_ranges_without_geom.first)
      end
      if options[:place] && (!options[:focus] || options[:focus] == :place)
        append_bounds_to_map_tag_attrs(map_tag_attrs, options[:place])
      end
    end
    { "data" => map_tag_attrs.delete_if{ |k,v| v.nil? } }
  end

  def observations_for_map_tag_attrs(options)
    return if options[:observations].blank?
    options[:observations].collect{ |o|
      o.to_json(:viewer => current_user,
        :force_coordinate_visibility => @coordinates_viewable,
        :include => [ { :user => { :only => :login },
          :taxon => { :only => [ :id, :name ] } },
          :iconic_taxon ],
        :methods => [ :iconic_taxon_name ],
        :except => [ :description ] ).html_safe
    }
  end

  def append_bounds_to_map_tag_attrs(map_tag_attrs, instance_with_bounds)
    return unless instance_with_bounds && instance_with_bounds.respond_to?(:bounds)
    bounds = instance_with_bounds.bounds
    if bounds && bounds[:min_x]
      unless map_tag_attrs["min-x"] && bounds[:min_x] > map_tag_attrs["min-x"]
        map_tag_attrs["min-x"] = bounds[:min_x]
      end
      unless map_tag_attrs["min-y"] && bounds[:min_y] > map_tag_attrs["min-y"]
        map_tag_attrs["min-y"] = bounds[:min_y]
      end
      unless map_tag_attrs["max-x"] && bounds[:max_x] < map_tag_attrs["max-x"]
        map_tag_attrs["max-x"] = bounds[:max_x]
      end
      unless map_tag_attrs["max-y"] && bounds[:max_y] < map_tag_attrs["max-y"]
        map_tag_attrs["max-y"] = bounds[:max_y]
      end
    end
  end

  def google_static_map_for_observation_url(o, options = {})
    return if CONFIG.google.blank? || CONFIG.google.simple_key.blank?
    url_for_options = {
      :host => 'maps.google.com',
      :controller => 'maps/api/staticmap',
      :center => "#{o.latitude},#{o.longitude}",
      :zoom => o.map_scale || 7,
      :size => '200x200',
      :sensor => 'false',
      :markers => "color:0x#{iconic_taxon_color(o.iconic_taxon_id)}|#{o.latitude},#{o.longitude}",
      :port => false,
      :key => CONFIG.google.simple_key
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
        s += "#{separator}#{t(:all_rights_reserved)}"
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
    elsif record.is_a?(Photo) || record.is_a?(Sound)
      user_name = ""
      if record.user && record.editable_by?(record.user)
        user_name = record.user.name
        user_name = record.user.login if user_name.blank?
      end
      user_name = record.native_realname if user_name.blank?
      user_name = record.native_username if user_name.blank?
      user_name = record.user.try(:name) if user_name.blank?
      user_name = record.user.try(:login) if user_name.blank?
      user_name = t(:unknown) if user_name.blank?
      s = if record.copyrighted? || record.creative_commons?
        "&copy; #{user_name}"
      else
        t(:no_known_copyright_restrictions, :name => user_name)
      end

      if record.copyrighted?
        s += "#{separator}#{t(:all_rights_reserved)}"
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
          c.html_safe + link_to(t(:some_rights_reserved), url)
        end
      end
    else
      s = record.attribution if record.respond_to?(:attribution)
      s ||= "&copy; #{user_name}"
    end
    content_tag(:span, s.html_safe, :class => "rights verticalmiddle")
  end
  
  def url_for_license(code)
    return nil if code.blank?
    if info = Photo::LICENSE_INFO.detect{|k,v| v[:code] == code}.try(:last)
      info[:url]
    elsif code =~ /CC\-/
      "http://creativecommons.org/licenses/#{code[/CC\-(.+)/, 1].downcase}/3.0/"
    end
  end
  
  def update_image_for(update, options = {})
    options[:style] = "max-width: 48px; vertical-align:middle; #{options[:style]}"
    resource = if @update_cache && @update_cache[update.resource_type.underscore.pluralize.to_sym]
      @update_cache[update.resource_type.underscore.pluralize.to_sym][update.resource_id]
    end
    resource ||= update.resource
    resource = update.resource.flaggable if update.resource_type == "Flag"
    case resource.class.name
    when "User"
      image_tag("#{root_url}#{resource.icon.url(:thumb)}", options.merge(:alt => "#{resource.login} icon"))
    when "Observation"
      observation_image(resource, options.merge(:size => "square"))
    when "Project"
      image_tag("#{root_url}#{resource.icon.url(:thumb)}", options)
    when "ProjectUserInvitation"
      image_tag("#{root_url}#{resource.user.icon.url(:thumb)}", options.merge(:alt => "#{resource.user.login} icon"))
    when "AssessmentSection"
      image_tag("#{root_url}#{resource.assessment.project.icon.url(:thumb)}", options)
    when "ListedTaxon"
      image_tag("#{root_url}images/checklist-icon-color-32px.png", options)
    when "Post"
      image_tag("#{root_url}#{resource.user.icon.url(:thumb)}", options)
    when "Place"
      image_tag("#{root_url}images/icon-maps.png", options)
    when "Taxon"
      taxon_image(resource, {:size => "square", :width => 48}.merge(options))
    when "TaxonSplit", "TaxonMerge", "TaxonSwap", "TaxonDrop", "TaxonStage"
      image_tag("#{root_url}images/#{resource.class.name.underscore}-aaaaaa-48px.png", options)
    when "ObservationField"
      image_tag("#{root_url}images/notebook-icon-color-155px-shadow.jpg", options)
    else
      image_tag("#{root_url}images/logo-cccccc-20px.png", options)
    end
  end
  
  def update_tagline_for(update, options = {})
    resource = if @update_cache && @update_cache[update.resource_type.underscore.pluralize.to_sym]
      @update_cache[update.resource_type.underscore.pluralize.to_sym][update.resource_id]
    end
    resource ||= update.resource
    notifier = if @update_cache && @update_cache[update.notifier_type.underscore.pluralize.to_sym]
      @update_cache[update.notifier_type.underscore.pluralize.to_sym][update.notifier_id]
    end
    notifier ||= update.notifier
    if notifier.respond_to?(:user) && (notifier_user = update_cached(notifier, :user) || notifier.user)
      notifier_user_link = options[:skip_links] ? notifier_user.login : link_to(notifier_user.login, person_url(notifier_user))
    end
    class_name_key = update.resource.class.to_s.underscore
    class_name = class_name_key.humanize.downcase
    resource_link = if options[:skip_links]
      t(class_name_key, :default => class_name_key).downcase
    else
      link_to(t(class_name_key, :default => class_name_key).downcase, url_for_resource_with_host(resource))
    end

    if notifier.is_a?(Comment) || notifier.is_a?(Identification)
      noun = "#{class_name =~ /^[aeiou]/i ? t(:an) : t(:a)} #{resource_link}".html_safe
      if resource_name = resource.try_methods(:name, :title)
        noun += " (\"#{truncate(resource_name, :length => 30)}\")".html_safe
      end
      s = activity_snippet(update, notifier, notifier_user, options.merge(
        :noun => noun
      ))
      return s.html_safe
    end

    case update.resource_type
    when "User"
      if update.notifier_type == "Post"
        post = notifier
        title = if options[:skip_links]
          resource.login
        else
          link_to_user(resource)
        end
        article = if options[:count] && options[:count].to_i == 1
          t(:x_wrote_a_new_post_html, :x => title)
        else
          t(:x_wrote_y_new_posts_html, :x => title, :y => options[:count])
        end
      else
        if options[:count].to_i == 1
          t(:user_added_an_observation_html, 
            :user => options[:skip_links] ? resource.login : link_to(resource.login, url_for_resource_with_host(resource)))
        else
          t(:user_added_x_observations_html,
            :user => options[:skip_links] ? resource.login : link_to(resource.login, url_for_resource_with_host(resource)),
            :x => options[:count])
        end
      end
    when "Observation"
      if notifier.is_a?(ProjectInvitation)
        t(:user_invited_your_x_to_a_project_html, :user => notifier_user_link, :x => resource_link)
      elsif notifier.is_a?(ObservationFieldValue)
        t(:user_added_an_observation_field_html, :user => notifier_user_link, :field_name => truncate(notifier.observation_field.name), 
          :owner => you_or_login(resource.user, :capitalize_it => false))
      else
        "unknown"
      end
    when "Project"
      project = resource
      if update.notifier_type == "Post"
        post = notifier
        title = if options[:skip_links]
          project.title
        else
          link_to(project.title, project_journal_post_url(:project_id => project.id, :id => post.id))
        end
        article = if options[:count] && options[:count].to_i == 1
          t(:x_wrote_a_new_post_html, :x => title)
        else
          t(:x_wrote_y_new_posts_html, :x => title, :y => options[:count])
        end
      else
        title = if options[:skip_links]
          project.title
        else
          link_to(project.title, url_for_resource_with_host(project))
        end
        t(:curators_changed_for_x_html, :x => title)
      end
    when "ProjectUserInvitation"
      if options[:skip_links]
        t(:user_invited_you_to_join_project, :user => notifier_user.login, :project => resource.project.title)
      else
        t(:user_invited_you_to_join_project, :user => notifier_user_link, :project => link_to(resource.project.title, project_url(resource.project))).html_safe
      end
    when "Place"
      t(:new_observations_from_place_html, 
        :place => options[:skip_links] ? resource.display_name : link_to(resource.display_name, url_for_resource_with_host(resource)))
    when "Taxon"
      name = render( 
        :partial => "shared/taxon", 
        :object => resource,
        :locals => {
          :link_url => (options[:skip_links] == true ? nil : url_for_resource_with_host(resource))
        })
      t(:new_observations_of_x_html, :x => name)
    when "Flag"
      noun = t(:a_flag_for_x, :x => resource.flaggable.try_methods(:name, :title, :to_plain_s))
      if notifier.is_a?(Flag)
        subject = options[:skip_links] ? notifier.resolver.login : link_to(notifier.resolver.login, person_url(notifier.resolver))
        t(:subject_resolved_noun_html, :subject => subject, :noun => noun)
      else
        activity_snippet(update, notifier, notifier_user, options.merge(:noun => noun))
      end
    when "TaxonChange"
      notifier_user = update_cached(resource, :committer)
      if notifier_user
        notifier_class_name = t(resource.class.name.underscore)
        subject = options[:skip_links] ? notifier_user.login : link_to(notifier_user.login, person_url(notifier_user)).html_safe
        object = "#{notifier_class_name =~ /^[aeiou]/i ? t(:an) : t(:a)} <strong>#{notifier_class_name}</strong>".html_safe
        t(:subject_committed_thing_affecting_stuff_html, 
          :subject => subject, 
          :thing => object, 
          :stuff => commas_and(resource.input_taxa.map(&:name)))
      else
        t(:subject_affecting_stuff_html, 
          :subject => t(resource.class.name.underscore), 
          :stuff => commas_and(resource.input_taxa.map(&:name)))
      end
    else
      "update"
    end
  end

  def activity_snippet(update, notifier, notifier_user, options = {})
    if update.notification == "activity" && notifier_user
      notifier_class_name_key = notifier.class.to_s.underscore
      notifier_class_name = t(notifier_class_name_key).downcase
      key = "user_added_"
      opts = {
        :user => options[:skip_links] ? notifier_user.login : link_to(notifier_user.login, person_url(notifier_user)),
        :x => notifier_class_name
      }
      key += notifier_class_name =~ /^[aeiou]/i ? 'an' : 'a'
      key += '_x_to'
    else
      key = "new_activity_on"
      opts = {}
    end

    if options[:noun]
      key += '_noun'
      opts[:noun] = options[:noun]
    end
    if update.resource_owner
      key += '_by'
      opts[:by] = you_or_login(update.resource_owner, :capitalize_it => false)
    end
    key += '_html'

    t(key, opts)
  end
  
  def url_for_resource_with_host(resource)
    base_url = if (u = @user) && u.site
      u.site.url
    end
    base_url ||= CONFIG.site_url || root_url
    "#{base_url}#{url_for(resource)}"
  end
  
  def commas_and(list, options = {})
    return list.first.to_s.html_safe if list.size == 1
    return list.join(" #{t :and} ").html_safe if list.size == 2
    options[:separator] ||= ","
    options[:and] ||= t(:and)
    "#{list[0..-2].join(', ')}#{options[:separator]} #{options[:and]} #{list.last}".html_safe
  end
  
  def update_cached(record, association)
    unless record.respond_to?("#{association}_id")
      return record.send(association)
    end
    cache_key = record.send("#{association}_id")
    cached = if @update_cache && @update_cache[association.to_s.pluralize.to_sym]
      @update_cache[association.to_s.pluralize.to_sym][cache_key]
    end
    unless cached
      @update_cache ||= {}
      @update_cache[association.to_s.pluralize.to_sym] ||= {}
      @update_cache[association.to_s.pluralize.to_sym][cache_key] = record.send(association)
    end
    @update_cache[association.to_s.pluralize.to_sym][cache_key]
  end

  def observation_field_value_for(ofv)
    if ofv.observation_field.datatype == ObservationField::TAXON
      if taxon = Taxon.find_by_id(ofv.value)
        content_tag(:span, "&nbsp;".html_safe, 
            :class => "iconic_taxon_sprite #{taxon.iconic_taxon_name.to_s.downcase} selected") + 
          render("shared/taxon", :taxon => taxon, :link_url => taxon)
      else
        "unknown"
      end
    elsif ofv.observation_field.datatype == ObservationField::DNA
      css_class = "dna"
      css_class += case ofv.observation_field.name
      when /(coi|cox1)/i then " bold-coi" 
      when /its/i then " bold-its"
      when /rbcl|matk/i then " bold-matk"
      else ""
      end
      content_tag(:div, ofv.value.gsub(/\s/, ''), :class => css_class)
    else
      ofv.value
    end
  end

  def cite(citation = nil, &block)
    @_citations ||= []
    if citation.blank? && block_given?
      citation = capture(&block)
    end
    citations = [citation].flatten
    links = citations.map do |c|
      c = c.citation if c.is_a?(Source)
      @_citations << c unless @_citations.include?(c)
      i = @_citations.index(c) + 1
      link_to(i, "#ref#{i}", :name => "cit#{i}")
    end
    content_tag :sup, links.uniq.sort.join(',').html_safe
  end

  def references(options = {})
    return if @_citations.blank?
    lis = ""
    @_citations.each_with_index do |citation, i|
      lis += if options[:linked]
        l = link_to i+1, "#cit#{i+1}"
        content_tag(:li, "#{l}. #{citation}".html_safe, :class => "reference", :id => "ref#{i+1}")
      else
        content_tag(:li, citation.html_safe, :class => "reference", :id => "ref#{i+1}")
      end
    end
    if options[:linked]
      content_tag :ul, lis.html_safe, :class => "references"
    else
      content_tag :ol, lis.html_safe, :class => "references"
    end
  end

  def establishment_blob(listed_taxon, options = {})
    icon_class = listed_taxon.introduced? ? 'ui-icon-notice' : 'ui-icon-star'
    tip_class = listed_taxon.introduced? ? 'ui-tooltip-error' : 'ui-tooltip-success'
    tip = "<strong>#{t("establishment.#{(listed_taxon.establishment_means)}", :default => listed_taxon.establishment_means).capitalize}"
    tip += " #{t(:in)} #{listed_taxon.place.display_name}" if options[:show_place_name] && listed_taxon.place
    tip += ":</strong> #{t("establishment_means_descriptions.#{ListedTaxon::ESTABLISHMENT_MEANS_DESCRIPTIONS[listed_taxon.establishment_means].gsub('-','_').gsub(' ','_').downcase}", :default => ListedTaxon::ESTABLISHMENT_MEANS_DESCRIPTIONS[listed_taxon.establishment_means])}"
    blob_attrs = {
      :class => "blob #{listed_taxon.introduced? ? 'introduced' : listed_taxon.establishment_means.underscore} #{options[:class]}", 
      "data-tip" => tip, 
      "data-tip-position-at" => "bottom center", 
      "data-tip-style-classes" => "#{tip_class} ui-tooltip-shadow", 
      :title => listed_taxon.establishment_means.capitalize
    }
    content_tag :div, blob_attrs do
      content_tag :span, :class => "inlineblock ui-icon #{icon_class}" do
        listed_taxon.introduced? ? 'I' : listed_taxon.establishment_means.chars.to_a[0].upcase
      end
    end
  end

  def uri_join(*args)
    URI.join(*args).to_s
  rescue URI::InvalidURIError
    args.join('/').gsub(/\/+/, '/')
  end

  def google_maps_js(options = {})
    sensor = options[:sensor] ? 'true' : 'false'
    "<script type='text/javascript' src='http#{'s' if request.ssl?}://maps.google.com/maps/api/js?sensor=#{sensor}'></script>".html_safe
  end

  def leaflet_js(options = {})
    h = <<-HTML
      #{ stylesheet_link_tag('http://cdn.leafletjs.com/leaflet-0.6.4/leaflet.css') }
      <!--[if lte IE 8]>
          #{ stylesheet_link_tag('http://cdn.leafletjs.com/leaflet-0.6.4/leaflet.ie.css') }
      <![endif]-->
      #{ javascript_include_tag('http://cdn.leafletjs.com/leaflet-0.6.4/leaflet.js') }
    HTML
    if options[:draw]
      h += <<-HTML
        #{ stylesheet_link_tag('leaflet.draw/leaflet.draw.css') }
        <!--[if lte IE 8]>
            #{ stylesheet_link_tag('leaflet.draw/leaflet.draw.ie.css') }
        <![endif]-->
        #{ javascript_include_tag('leaflet.draw/leaflet.draw.js') }
      HTML
    end
    raw h
  end

  def machine_tag_pieces(tag)
    pieces = tag.split('=')
    predicate, value = pieces
    if pieces.size == 1
      value, namespace, predicate = pieces
    elsif predicate =~ /\:/
      namespace, predicate = predicate.split(':')
    else
      predicate, value = pieces
    end
    [namespace, predicate, value]
  end

  def tag_to_xml(tag, xml)
    namespace, predicate, value = machine_tag_pieces(tag)
    xml.tag tag, :predicate => predicate, :namespace => namespace, :value => value
  end

  def flexible_post_path(post, options = {})
    return trip_path(post, options) if post.is_a?(Trip)
    if post.parent_type == "User"
      journal_post_path(post.user.login, post)
    else
      project_journal_post_path(post.parent.slug, post)
    end
  end

  def edit_post_path(post, options = {})
    return edit_trip_path(post, options) if post.is_a?(Trip)
    if post.parent_type == "User"
      edit_journal_post_path(post.user.login, post)
    else
      edit_project_journal_post_path(post.parent.slug, post)
    end
  end

  def feature_test(test, options = {}, &block)
    options[:audience] ||= []
    test_enabled = params[:test] && params[:test] == test.to_s
    user_authorized = true
    user_authorized = current_user.try(:is_admin?) if options[:audience].include?(:admins) 
    user_authoried = current_user.try(:is_curator?) if options[:audience].include?(:curators)
    user_authoried = logged_in? if options[:audience].include?(:users)
    if test_enabled && user_authorized
      @feature_test = test
      content_tag(:span, capture(&block), :class => "feature_test")
    else
      ""
    end
  end

  def favicon_url_for(url)
    uri = URI.parse(url) rescue nil
    "http://www.google.com/s2/favicons?domain=#{uri.try(:host)}"
  end

  # http://jfire.io/blog/2012/04/30/how-to-securely-bootstrap-json-in-a-rails-view/
  def json_escape(s)
    result = s.to_s.gsub('/', '\/')
    s.html_safe? ? result.html_safe : result
  end
  
end
