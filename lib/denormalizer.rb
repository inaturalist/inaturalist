class Denormalizer

  # Called like:
  #   Denormalize::each_taxon_batch_with_index(10000) do |taxa, index, total_batches|
  #     ...
  #   end
  def self.each_taxon_batch_with_index(batch_size)
    index = 0
    batch_size = batch_size.to_f
    total_taxa = Taxon.count
    total_batches = (total_taxa / batch_size).ceil
    Taxon.select([ :id, :ancestry ]).find_in_batches(batch_size: batch_size) do |taxa|
      index +=1
      Rails.logger.debug "[DEBUG] Processing batch #{ index } of #{ total_batches }"
      yield(taxa, index, total_batches)
    end
  end

  protected

  def self.psql
    ActiveRecord::Base.connection
  end

end

Dir["#{File.dirname(__FILE__)}/denormalizer/*.rb"].each { |f| load(f) }
