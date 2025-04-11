FactoryBot.define do
  factory :photo_metadata do
    photo
    metadata { {} }
  end
end
