FactoryBot.define do
  factory :sound do
    user
    sequence :native_sound_id
  end
end
