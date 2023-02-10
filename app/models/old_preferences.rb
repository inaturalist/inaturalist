class OldPreferences
  PREFERENCES = [
    :comment_email_notification,
    :identification_email_notification,
    :project_invitation_email_notification,
    :lists_by_login_sort,
    :lists_by_login_order,
    :per_page
  ]
  
  ALLOWED = {
    :comment_email_notification => [true, false],
    :identification_email_notification => [true, false],
    :project_invitation_email_notification => [true, false],
    :lists_by_login_sort => ListsController::LIST_SORTS,
    :lists_by_login_order => ListsController::LIST_ORDERS,
    :per_page => ApplicationController::PER_PAGES
  }
  
  DEFAULTS = {
    :comment_email_notification => true,
    :identification_email_notification => true,
    :project_invitation_email_notification => true,
    :lists_by_login_sort => 'id',
    :lists_by_login_order => 'asc',
    :per_page => 30
  }
  
  NOTIFICATION_ATTRIBUTES = [
    :comment_email_notification,
    :identification_email_notification,
    :project_invitation_email_notification
  ]
  
  # Set all prefs as instance vars
  PREFERENCES.each do |pref|
    default = DEFAULTS[pref]
    default = "'#{default}'" if default.is_a?(String)
    class_eval <<-EOT
      attr_accessor :#{pref}
      def #{pref}
        @#{pref}.nil? ? #{default} : @#{pref}
      end
      
      def #{pref}=(val)
        return unless allowed?(:#{pref}, val)
        instance_variable_set :@#{pref}, val
      end
    EOT
  end
  
  def initialize
    # Set all prefs to default values
    PREFERENCES.each do |pref, default|
      instance_variable_set "@#{pref}", default
    end
  end
  
  def allowed?(preference, val)
    ALLOWED[preference] && ALLOWED[preference].include?(val)
  end
  
  def update(attrs = {})
    attrs.each do |key, value|
      # HACK: this will totally screw up preferences that actually should be 
      # 1 or 0.  Ugh
      value = true if value == '1'
      value = false if value == '0'
      value = value.to_i if value.respond_to?(:to_i) && value.to_i != 0
      send("#{key}=", value) if respond_to?(key.to_sym)
    end
  end
end
