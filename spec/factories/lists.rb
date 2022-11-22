FactoryBot.define do
  factory :list do
    user
    title { Faker::Lorem.sentence }
    place { build :place, :with_geom }

    factory :check_list, class: CheckList do
      type { CheckList }
    end

    factory :project_list, class: ProjectList do
      type { ProjectList }
    end
  end
end
