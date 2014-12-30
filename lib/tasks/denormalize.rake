namespace :denormalize do

  desc "Create some denormalized tables for the windshaft tiler (~4 minutes)."
  task :windshaft => :environment do
    WindshaftDenormalizer.denormalize
  end

  desc "Denormalize taxon ancestries (~1.5 minutes)."
  task :ancestries => :environment do
    AncestryDenormalizer.denormalize
  end

end
