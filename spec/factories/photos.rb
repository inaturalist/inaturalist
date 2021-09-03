FactoryBot.define do
  factory :photo do
    user
    sequence :native_photo_id
  end
end
