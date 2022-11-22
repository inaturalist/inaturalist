class TripTaxon < ApplicationRecord
  belongs_to :trip, :inverse_of => :trip_taxa
  belongs_to :taxon
  validates_uniqueness_of :taxon_id, :scope => :trip_id
  validates_presence_of :taxon

  delegate :ancestry, :ancestor_ids, to: :taxon

  def serializable_hash(opts = nil)
    # don't use delete here, it will just remove the option for all 
    # subsequent records in an array
    options = opts ? opts.clone : { }
    options[:methods] ||= []
    options[:methods] += [:created_at_utc, :updated_at_utc]
    if options[:except]
      options[:methods] = options[:methods] - options[:except]
    end
    options[:methods].uniq!
    h = super(options)
    h
  end

end
