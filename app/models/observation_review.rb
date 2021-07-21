class ObservationReview < ActiveRecord::Base

  belongs_to :observation
  belongs_to :user

  def update_observation_index( options = { } )
    update_script_source = reviewed ? "
      if ( !ctx._source.reviewed_by.contains( params.user_id ) ) {
        ctx._source.reviewed_by.add( params.user_id );
      } else { ctx.op = 'none' }" : "
      if ( ctx._source.reviewed_by.contains( params.user_id ) ) {
        ctx._source.reviewed_by.remove( ctx._source.reviewed_by.indexOf( params.user_id ) );
      } else { ctx.op = 'none' }";

    Observation.__elasticsearch__.client.update(
      index: Observation.index_name,
      id: observation_id,
      refresh: ( options[:wait_for_refresh] || Rails.env.test? ) ? "wait_for" : false,
      retry_on_conflict: 10,
      body: {
        script: {
          source: update_script_source,
          params: {
            user_id: user_id
          }
        }
      }
    )
  end

  def self.merge_future_duplicates( reject, keeper )
    unless reject.is_a?( User ) || reject.is_a?( Observation )
      raise "ObservationReview.merge_future_duplicates only works for observations right now"
    end
    reject.observation_reviews.delete_all
  end

end
