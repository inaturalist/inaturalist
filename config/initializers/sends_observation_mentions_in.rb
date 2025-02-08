# frozen_string_literal: true

module SendsObservationMentionsIn
  def self.included( base )
    base.extend ::SendsObservationMentionsIn::ClassMethods
  end

  module ClassMethods
    def sends_observation_mentions_in( field )
      return if included_modules.include?( ::SendsObservationMentionsIn::InstanceMethods )

      include SendsObservationMentionsIn::InstanceMethods
      cattr_accessor :observation_mentions_field
      self.observation_mentions_field = field
      has_many :observation_mentions, as: :sender, inverse_of: :sender, dependent: :destroy
      after_save :process_observation_mentions
    end
  end

  module InstanceMethods
    def process_observation_mentions
      field = self.class.observation_mentions_field
      return unless send( "#{field}_previously_changed?" )

      old_ids = ObservationMention.extract_observation_ids( send( "#{field}_previously_was" ) )
      cur_ids = ObservationMention.extract_observation_ids( send( field ) )
      removed_ids = old_ids - cur_ids
      new_ids = cur_ids - old_ids

      ObservationMention.where( observation_id: removed_ids, sender: self ).destroy_all
      new_ids.each do | observation_id |
        m = ObservationMention.new( observation_id: observation_id, sender: self )
        unless m.save
          Rails.logger.error "failed to save ObservationMention in #{self}: #{m.errors.full_messages.to_sentence}"
        end
      end
    end
  end
end

ActiveRecord::Base.include SendsObservationMentionsIn
