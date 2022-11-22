FactoryBot.define do
  factory :email_suppression do
    user
    email { Faker::Internet.email }
    suppression_type { EmailSuppression::TRANSACTIONAL_EMAILS }
  end
end
