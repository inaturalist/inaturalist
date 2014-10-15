class SetCaptiveOnObservations < ActiveRecord::Migration
  def up
    batch = 0
    Observation.includes(:quality_metrics).
        where("quality_metrics.metric = ?", QualityMetric::WILD).
        find_in_batches(batch_size: 10000) do |observations|
      say "[#{Time.now}] Batch #{batch}"
      Observation.connection.transaction do
        observations.each do |o|
          o.set_captive
        end
      end
      batch += 1
    end
  end

  def down
    # do nothing
  end
end
