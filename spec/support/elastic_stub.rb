module ElasticStub
  def elastic_stub_observations(count=1, &block)
    observations = count.times.with_object([]) do |_i, arr|
                     obs = block.call
                     obs.__elasticsearch__.index_document
                     arr << obs
                   end
    Observation.__elasticsearch__.refresh_index!
    count == 1 ? observations.first : observations
  end
end
