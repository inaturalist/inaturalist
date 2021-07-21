namespace :denormalize do

  desc "Denormalize taxon ancestries (~5 minutes)."
  task :ancestries => :environment do
    AncestryDenormalizer.denormalize
  end

end
