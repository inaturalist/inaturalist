# frozen_string_literal: true

FactoryBot.define do
  factory :subscription do
    resource { create :observation }
    user { association( :user_privilege, privilege: UserPrivilege::INTERACTION ).user }
  end
end
