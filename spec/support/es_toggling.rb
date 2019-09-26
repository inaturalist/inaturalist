module EsToggling
  # Turn on elastic indexing for certain models. We do this selectively b/c
  # updating ES slows down the specs.
  def enable_elastic_indexing(*args)
    classes = [args].flatten
    classes.each do |klass|
      begin
        klass.__elasticsearch__.delete_index!
      rescue Exception => e
        raise e unless e.class.to_s =~ /NotFound/
      end
      klass.__elasticsearch__.create_index!
      ElasticModel.wait_until_index_exists(klass.index_name)
      klass.send :after_save, :elastic_index!
      klass.send :after_destroy, :elastic_delete!
      klass.send :after_touch, :elastic_index!
    end
  end

  # Turn off elastic indexing for certain models. Make sure to do this after
  # specs if you used enable_elastic_indexing
  def disable_elastic_indexing(*args)
    classes = [args].flatten
    classes.each do |klass|
      klass.send :skip_callback, :save, :after, :elastic_index!
      klass.send :skip_callback, :destroy, :after, :elastic_delete!
      klass.send :skip_callback, :touch, :after, :elastic_index!
      klass.__elasticsearch__.delete_index!
    end
  end

  def with_es_enabled(*classes)
    enable_elastic_indexing(*classes)
    yield
  ensure
    disable_elastic_indexing(*classes)
  end

  # Currently this is used to skip observations indexing after creation of
  # photos (to speed up tests) but could also be applied in other situations
  def stub_elastic_indexing(model)
    allow(model).to receive(:elastic_index!)
  end

  # calling Observation.update_stats_for_observations_of is a side effect of
  # moving a taxon. As sometimes in specs we move taxons but don't care about 
  # observation stats, it makes sense to stub the functionality to speed up tests
  def stub_observations_stats_update
    allow(Observation).to receive(:update_stats_for_observations_of)
  end
end

module EsTogglingHelper
  def with_es_enabled_for_each(*classes)
    before { enable_elastic_indexing(*classes) }
    after { disable_elastic_indexing(*classes) }
  end

  def with_es_enabled_for_group(*classes)
    before(:all) { enable_elastic_indexing(*classes) }
    after(:all) { disable_elastic_indexing(*classes) }
  end
end
