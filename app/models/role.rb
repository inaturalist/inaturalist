class Role < ApplicationRecord
  ADMIN = "admin".freeze
  CURATOR = "curator".freeze
  APP_OWNER = "app owner".freeze
  ADMIN_ROLE = Role.find_or_create_by( name: ADMIN )
  CURATOR_ROLE = Role.find_or_create_by( name: CURATOR )
  APP_OWNER_ROLE = Role.find_or_create_by( name: APP_OWNER )
end
