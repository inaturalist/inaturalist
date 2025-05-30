# frozen_string_literal: true

class PicasaPhoto < Photo
  validates_presence_of :native_photo_id
  validate :licensed_if_no_user
end
