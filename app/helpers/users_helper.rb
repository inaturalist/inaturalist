module UsersHelper

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
  def link_to_user(user, options = { missing: t(:deleted_user) }, &block)
    return options[:missing] unless user
    url = options.delete(:url) || person_url(user.login)
    options.reverse_merge! :content_method => :login, :title_method => :login, :class => :nickname
    if block_given?
      content_text = capture(&block)
    else
      content_text = options.delete(:content_text)
      content_text ||= user.send(options.delete(:content_method))
    end
    options[:title] ||= user.send(options.delete(:title_method))
    link_to content_text, url, options
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
        t(:your_, :default => "your").capitalize
      else
        t(:your_, :default => "your")
      end
    else
      t :possessive_user, :user => user.login
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
      capitalize_it ? t(:you_) : t(:you)
    else
      user.login
    end
  end
end
