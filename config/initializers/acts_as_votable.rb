# frozen_string_literal: true

module ActsAsVotable
  class Vote
    include HasSubscribers
    # requires_privilege :interaction, unless: proc {| vote |
    #   vote.votable.respond_to?( :user ) && vote.votable.user.id == vote.user_id
    # }

    blockable_by ->( vote ) { vote.votable.try( :user ) }

    belongs_to :observation, ->( vote ) { where( ( vote.votable_type == "Observation" ) ? "true" : "false" ) },
      foreign_key: "votable_id"
    belongs_to :identification, ->( vote ) { where( ( vote.votable_type == "Identification" ) ? "true" : "false" ) },
      foreign_key: "votable_id"

    validates_uniqueness_of :vote_scope,
      scope: [:votable_type, :votable_id, :voter_type, :voter_id]

    notifies_owner_of :votable, notification: "activity",
      unless: lambda {| record |
        !record.vote_scope.blank? || record.user_id == record.votable.try( :user_id )
      }

    auto_subscribes :user, to: :votable

    after_save :run_votable_callback
    after_destroy :run_votable_callback

    attr_accessor :bulk_delete

    alias user voter

    def user_id
      voter_id
    end

    def unsubscribable?
      votable&.class&.const_defined?( "SUBSCRIBABLE" ) &&
        votable&.class&.const_get( "SUBSCRIBABLE" ) == false
    end

    def run_votable_callback
      return if bulk_delete
      return unless votable.respond_to?( :votable_callback )

      votable.votable_callback
    end

    def as_indexed_json
      {
        id: id,
        vote_flag: vote_flag,
        vote_scope: vote_scope,
        user_id: user_id,
        created_at: created_at
      }
    end
  end

  module Votable
    def faves
      votes_for.where( vote_flag: true, vote_scope: nil )
    end

    def helpfulness_votes
      votes_for.where( vote_scope: "helpful" )
    end

    def votes
      votes_for.each_with_object( {} ) do | vote, memo |
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
