class PicasaIdentity < ActiveRecord::Base
  belongs_to :user
  before_save :set_token_created_at
  
  def set_token_created_at
    self.token_created_at = (token.blank? ? nil : Time.now) if token_changed?
  end
end
