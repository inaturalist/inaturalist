require 'has_subscribers'
module ActsAsVotable

  class Vote
    include HasSubscribers

    belongs_to :observation, -> { where(votes: { votable_type: "Observation" }) },
      foreign_key: "votable_id"
    belongs_to :identification, -> { where(votes: { votable_type: "Identification" }) },
      foreign_key: "votable_id"

    notifies_owner_of :votable, notification: "activity",
      queue_if: lambda { |record| record.vote_scope.blank? }

    auto_subscribes :user, to: :votable

    after_save :run_votable_callback
    after_destroy :run_votable_callback

    alias_method :user, :voter

    def user_id
      voter_id
    end

    def unsubscribable?
      votable &&
        votable.class.const_defined?("SUBSCRIBABLE") &&
        votable.class.const_get("SUBSCRIBABLE") == false
    end

    def run_votable_callback
      if votable.respond_to?(:votable_callback)
        votable.votable_callback
      end
    end

  end

  module Votable

    def faves
      votes_for.where(vote_flag: true, vote_scope: nil)
    end

    def helpfulness_votes
      votes_for.where(vote_scope: "helpful")
    end

    def votes
      votes_for.inject({}) do |memo, vote|
        memo[vote.vote_scope] ||= {}
        memo[vote.vote_scope][:up] ||= 0
        memo[vote.vote_scope][:down] ||= 0
        if vote.vote_flag?
          memo[vote.vote_scope][:up] += 1
        else
          memo[vote.vote_scope][:down] += 1
        end
        memo
      end
    end
  end

end