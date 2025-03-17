# frozen_string_literal: true

FactoryBot.define do
  factory :friendship do
    user { association( :user_privilege, privilege: UserPrivilege::INTERACTION ).user }
    friend { create :user }
  end
end
