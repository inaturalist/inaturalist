# frozen_string_literal: true

class DowncaseUserParentEmails < ActiveRecord::Migration[6.1]
  def up
    UserParent.find_each do | user_parent |
      # rubocop:disable Lint/SelfAssignment
      # setting email to itself, which will trigger the new `email=` method
      # that will downcase the email if it is not already
      user_parent.email = user_parent.email
      # rubocop:enable Lint/SelfAssignment
      next unless user_parent.changed?

      user_parent.save
    end
  end

  def down
    # irreversible
  end
end
