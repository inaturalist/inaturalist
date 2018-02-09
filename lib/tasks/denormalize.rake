namespace :denormalize do

  desc "Denormalize taxon ancestries (~1.5 minutes)."
  task :ancestries => :environment do
    AncestryDenormalizer.denormalize
  end

  desc "Denormalize places (~15 minutes)."
  task :places => :environment do
    PlaceDenormalizer.denormalize
  end

end
