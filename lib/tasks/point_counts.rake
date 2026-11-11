# frozen_string_literal: true

namespace :surveys do
  desc "Install the approved bird point-count pilot (OWNER_ID required); never rewrites a published version"
  task install_point_count: :environment do
    version = Surveys::PointCountProtocol.install!( owner: User.find( ENV.fetch( "OWNER_ID" ) ) )
    puts "Point-count v#{version.version_number}: #{version.status}"
  end
end
