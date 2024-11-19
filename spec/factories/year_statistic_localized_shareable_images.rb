# frozen_string_literal: true

FactoryBot.define do
  factory :year_statistic_localized_shareable_image do
    year_statistic
    locale { "en" }
  end
end
