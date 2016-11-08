require 'has_subscribers'
module ActsAsVotable

  class Vote
    include HasSubscribers

    belongs_to :observation, -> { where(votes: { votable_type: "Observation" }) },
      foreign_key: "votable_id"

    notifies_owner_of :votable, notification: "activity", 
      queue_if: lambda { |record| record.vote_scope.blank? }

    auto_subscribes :user, :to => :votable

    alias_method :user, :voter

    def user_id
      voter_id
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