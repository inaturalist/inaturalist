FactoryBot.define do
  factory :color do
    value { %w[red green blue].sample }
  end
end
