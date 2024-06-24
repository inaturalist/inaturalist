# frozen_string_literal: true

class LanguageDemoLog < ApplicationRecord
  validates_presence_of :search_term
  validates_presence_of :page
  validates_presence_of :votes
end
