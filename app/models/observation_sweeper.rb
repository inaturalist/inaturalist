class ObservationSweeper < ActionController::Caching::Sweeper
  begin
    observe Observation
  rescue ActiveRecord::NoDatabaseError
    puts "Database not connected, failed to observe Observation. Ignore if setting up for the first time"
  end
  include Shared::SweepersModule
  
  def after_create(observation)
    FileUtils.rm(private_page_cache_path(
      FakeView.observations_by_login_all_path(observation.user.login, :format => 'csv')
    ), :force => true)
    true
  end
  
  def after_update(observation)
    observation.listed_taxa.each {|lt| expire_listed_taxon(lt) }
    FileUtils.rm(private_page_cache_path(
      FakeView.observations_by_login_all_path(observation.user.login, :format => 'csv')
    ), :force => true)
    true
  end
  
  def after_destroy(observation)
    observation.listed_taxa.each {|lt| expire_listed_taxon(lt) }
    FileUtils.rm(private_page_cache_path(
      FakeView.observations_by_login_all_path(observation.user.login, :format => 'csv')
    ), :force => true)
    true
  end
end
