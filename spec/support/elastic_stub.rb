module ElasticStub
  # Instantiates an Observation in provided block
  # (ie `build_stubbed :observation`) and ES indexes the object as though it
  # were persisted. Allows for meaningful ES queries while bypassing
  # persistence and callback chains of the Observation
  #
  # @param [Integer] count Number of times to call block
  # @param [Proc] block Block to stub observation
  # @return [Observation] when count 1
  # @return [Array<Observation>] when count > 1
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
