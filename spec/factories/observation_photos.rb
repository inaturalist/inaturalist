FactoryBot.define do
  factory :observation_photo do
    observation
    transient { user { observation.user } }
    after(:build) { |op, eval| op.photo = build :photo, user: eval.user }
  end

  trait :local do
    transient { user { observation.user } }
    after(:build) { |op, eval| op.photo = build :local_photo, user: eval.user }
  end
end
