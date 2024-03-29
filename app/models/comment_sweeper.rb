class CommentSweeper  < ActionController::Caching::Sweeper
  begin
    observe Comment, Identification
  rescue ActiveRecord::NoDatabaseError
    puts "Database not connected, failed to observe Comment or Identification. Ignore if setting up for the first time"
  end
  include Shared::SweepersModule
  
  def after_save(item)
    sweep_comment(item)
    true
  end
  
  def after_destroy(item)
    sweep_comment(item)
    true
  end
  
  def sweep_comment(item)
    if item.is_a?(Comment)
      expire_listed_taxon(item.parent) if item.parent.is_a?(ListedTaxon)
    end
  end
end
