class Preferences
  attr_accessor :comment_email_notification
  attr_accessor :identification_email_notification
  
  NOTIFICATION_ATTRIBUTES = [
    :comment_email_notification,
    :identification_email_notification
  ]
  
  def initialize
    @comment_email_notification = true
    @identification_email_notification = true
  end
  
  def update_attributes(attrs = {})
    attrs.each do |key, value|
      # HACK: this will totally screw up preferences that actually should be 
      # 1 or 0.  Ugh
      value = true if value == '1'
      value = false if value == '0'
      send("#{key}=", value) if respond_to?(key.to_sym)
    end
  end
end