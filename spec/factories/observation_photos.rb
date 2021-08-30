FactoryBot.define do
  factory :observation_photo do
    observation
    photo
  end

  trait :local do
    photo { build :local_photo }
  end
end
