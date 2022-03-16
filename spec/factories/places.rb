FactoryBot.define do
  factory :place do
    user { build :curator }
    name { Faker::Lorem.sentence }
    display_name { name }
    slug { name.parameterize }
    uuid { Faker::Internet.uuid }
    admin_level { Place::STATE_LEVEL }
    latitude { 0.5 }
    longitude { 0.5 }

    after(:build) { |place| build :place_geometry, place: place }

    trait :with_geom do
      swlat { 0.0 }
      swlng { 0.0 }
      nelat { 1.0 }
      nelng { 1.0 }
      bbox_area { 1.0 }
    end

    trait :with_check_list do
      check_list
      # This is an interesting association where place `belongs_to :check_list` and `has_many :check_lists`
      # list `has_one :check_list_place, class_name: "Place", foreign_key: :check_list_id` and `belongs_to :place`
      after(:stub) { |place| place.check_list.place = place }
    end

  end
end
