module UsersHelper
  
  #
  # Use this to wrap view elements that the user can't access.
  # !! Note: this is an *interface*, not *security* feature !!
  # You need to do all access control at the controller level.
  #
  # Example:
  # <%= if_authorized?(:index,   User)  do link_to('List all users', users_path) end %> |
  # <%= if_authorized?(:edit,    @user) do link_to('Edit this user', edit_user_path) end %> |
  # <%= if_authorized?(:destroy, @user) do link_to 'Destroy', @user, :confirm => 'Are you sure?', :method => :delete end %> 
  #
  #
  def if_authorized?(action, resource, &block)
    if authorized?(action, resource)
      yield action, resource
    end
  end

  #
  # Link to user's page ('users/1')
  #
  # By default, their login is used as link text and link title (tooltip)
  #
  # Takes options
  # * :content_text => 'Content text in place of user.login', escaped with
  #   the standard h() function.
  # * :content_method => :user_instance_method_to_call_for_content_text
  # * :title_method => :user_instance_method_to_call_for_title_attribute
  # * as well as link_to()'s standard options
  #
  # Examples:
  #   link_to_user @user
  #   # => <a href="/users/3" title="barmy">barmy</a>
  #
  #   # if you've added a .name attribute:
  #  content_tag :span, :class => :vcard do
  #    (link_to_user user, :class => 'fn n', :title_method => :login, :content_method => :name) +
  #          ': ' + (content_tag :span, user.email, :class => 'email')
  #   end
  #   # => <span class="vcard"><a href="/users/3" title="barmy" class="fn n">Cyril Fotheringay-Phipps</a>: <span class="email">barmy@blandings.com</span></span>
  #
  #   link_to_user @user, :content_text => 'Your user page'
  #   # => <a href="/users/3" title="barmy" class="nickname">Your user page</a>
  #
  def link_to_user(user, options = {}, &block)
    return "deleted user" unless user
    options.reverse_merge! :content_method => :login, :title_method => :login, :class => :nickname
    if block_given?
      content_text = capture(&block)
    else
      content_text      = options.delete(:content_text)
      content_text    ||= user.send(options.delete(:content_method))
    end
    options[:title] ||= user.send(options.delete(:title_method))
    link_to content_text, person_url(user.login), options
  end

  #
  # Link to login page using remote ip address as link content
  #
  # The :title (and thus, tooltip) is set to the IP address 
  #
  # Examples:
  #   link_to_login_with_IP
  #   # => <a href="/login" title="169.69.69.69">169.69.69.69</a>
  #
  #   link_to_login_with_IP :content_text => 'not signed in'
  #   # => <a href="/login" title="169.69.69.69">not signed in</a>
  #
  def link_to_login_with_IP content_text=nil, options={}
    ip_addr           = request.remote_ip
    content_text    ||= ip_addr
    options.reverse_merge! :title => ip_addr
    if tag = options.delete(:tag)
      content_tag tag, h(content_text), options
    else
      link_to h(content_text), login_path, options
    end
  end

  #
  # Link to the current user's page (using link_to_user) or to the login page
  # (using link_to_login_with_IP).
  #
  def link_to_current_user(options={})
    if current_user
      link_to_user current_user, options
    else
      content_text = options.delete(:content_text) || 'not signed in'
      # kill ignored options from link_to_user
      [:content_method, :title_method].each{|opt| options.delete(opt)} 
      link_to_login_with_IP content_text, options
    end
  end
  
  
  # Below here, added for iNaturalist
  
  def friend_link(user, potential_friend)
    case !user.friends.include?(potential_friend)
    when true
      if user != potential_friend
        link_to "Add #{potential_friend.login} as a contact?", :controller => 'user', :action => 'add_friend', :id => potential_friend.id
      end
    when false # user is already a contact
      "%s is one of your contacts." % potential_friend.login
    end
  end
  
  def possessive(user, options = {})
    capitalize_it = options.delete(:capitalize)
    if logged_in? && current_user == user
      if capitalize_it
        "Your"
      else
        "your"
      end
    else
      "#{user.login}'s"
    end
  end

  def possessive_noun(user, noun, options = {})
    if is_me?(user)
      t(:second_person_possessive_singular, :noun => noun)
    else
      t(:third_person_possessive_singular, :noun => noun, :object_phrase => user.login)
    end
  end
  
  def you_or_login(user, options = {})
    capitalize_it = options.delete(:capitalize)
    if respond_to?(:user_signed_in?) && logged_in? && respond_to?(:current_user) && current_user == user
      capitalize_it ? t(:you).capitalize : t(:you).downcase
    else
      user.login
    end
  end
  
  def activity_stream_tagline(update, options = {})
    activity_object = options[:activity_object] || update.activity_object
    html = link_to update.user.login, person_path(update.user)
    html += " added "
    if update.batch_ids.blank?
      case update.activity_object_type 
      when "Post" 
        html += "a #{link_to "journal post", journal_post_path(update.user.login, activity_object)} "
      when "Comment" 
        html += "a #{link_to "comment", activity_object} "
        html += "on #{activity_object.parent_type.match(/^[aeiou]/i) ? 'an' : 'a'} "
        html += link_to(activity_object.parent_type.underscore.humanize.downcase, activity_object)
        if activity_object.parent.user 
          html += " by #{link_to activity_object.parent.user.login, activity_object.parent.user} "
        end 
      when "ListedTaxon" 
         html += "a taxon to #{link_to activity_object.list.title, activity_object} "
      when "List" 
        html += "a new list called #{link_to activity_object.title, activity_object }"
      else 
        html += update.activity_object_type.match(/^[aeiou]/i) ? 'an ' : 'a '
        html += link_to update.activity_object_type.underscore.humanize.downcase, activity_object
      end 
    else 
      html += pluralize update.batch_ids.split(',').size, update.activity_object_type.underscore.humanize.downcase 
    end 
    html += " at #{update.updated_at.strftime("%I:%S %p").downcase.gsub(/^0/, '')}"
    html
  end
  
  def activity_stream_body(update, options = {})
    activity_object = options[:activity_object] || update.activity_object
    return nil unless activity_object
    mobile = request.format.mobile?
    if update.batch_ids.blank?
      case update.activity_object_type
      when "Observation"
        content_tag(:div, render(:partial => "observations/cached_component", :object => activity_object), :class => "mini observations #{'compact' if mobile}")
      when "Identification" 
        render :partial => "identifications/identification_with_observation", :object => activity_object 
      when "ListedTaxon" 
        content_tag(:div, render(:partial => "lists/listed_taxon", :object => activity_object), :class => "listed_taxa plain_view")
      when "Post" 
        render :partial => "posts/post", :object => activity_object, :locals => { :truncate_length => 200 } 
      when "List" 
      when "Comment"
        if activity_object.parent.is_a?(Observation)
          content_tag(:div, render(:partial => "observations/cached_component", :object => activity_object.parent), :class => "mini observations #{'compact' if mobile}") +
          render(update.activity_object)
        else
          render(update.activity_object)
        end
      else 
        render update.activity_object 
      end 
    elsif batch_partial = activity_object.class.activity_stream_options[:batch_partial] 
      render :partial => batch_partial, :locals => { 
        :update => update,
        activity_object.class.to_s.underscore.pluralize.to_sym => @activity_objects_by_update_id[update.id]
      }
    end
  end
end
