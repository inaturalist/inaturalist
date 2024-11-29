# frozen_string_literal: true

class BlockedIp < ApplicationRecord
  belongs_to :user
end
