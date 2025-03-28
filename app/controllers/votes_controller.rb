class VotesController < ApplicationController
  before_action :doorkeeper_authorize!, :if => lambda { authenticate_with_oauth? }
  before_action :authenticate_user!, :unless => lambda { authenticated_with_oauth? }, except: [:by_login]
  before_action :load_votable, except: [:by_login, :destroy]
  before_action :load_user_by_login, only: :by_login
  before_action :load_vote, only: [:destroy]
  before_action :require_owner, only: [:destroy]

  layout "bootstrap"

  def destroy
    votable = @vote.votable
    @vote.destroy
    respond_to do |format|
      format.html do
        flash[:notice] = I18n.t(:deleted_vote)
        redirect_back_or_default votable
      end
      format.json { head :no_content }
    end
  end

  def vote
    success = @record.vote_by voter: current_user, vote: params[:vote], vote_scope: params[:scope]
    unless success
      # TODO: any way to get the error from vote_by without having to figure it out afterward
      # by creating a vote instance separately?
      failed_vote = ActsAsVotable::Vote.new(
        votable: @record,
        voter: current_user,
        vote_scope: params[:scope]
      )
      failed_vote.validate
      errors = failed_vote.errors
    end
    respond_to do |format|
      format.html do
        if errors&.any?
          flash[:error] = errors.full_messages.to_sentence
        end
        redirect_to @record
      end
      format.json do
        if errors&.any?
          render status: :unprocessable_entity,
            json: { error: errors.full_messages }
        else
          render json: @record.as_json(methods: [:votes])
        end
      end
    end
  end

  def unvote
    @record.unvote voter: current_user, vote: params[:vote], vote_scope: params[:scope]
    # ActsAsVotable uses delete_all, which bypasses after_destroy :run_votable_callback
    @record.votable_callback if @record.respond_to?( :votable_callback )
    respond_to do |format|
      format.html do
        redirect_to @record
      end
      format.json { head :no_content }
    end
  end

  def by_login
    @votes = @selected_user.votes.where(vote_scope: nil).
      where(votable_type: "Observation").
      order("votes.id DESC").page(params[:page]).per_page(100)
    ActsAsVotable::Vote.preload_associations(@votes, votable: [ 
        :sounds,
        :stored_preferences,
        :quality_metrics,
        :projects,
        :flags,
        { photos: [:flags, :file_prefix, :file_extension] },
        { user: [:stored_preferences, :friendships] },
        { taxon: [ { taxon_names: :place_taxon_names }, :taxon_descriptions] },
        { iconic_taxon: :taxon_descriptions }
      ])
    respond_to do |format|
      format.html
    end
  end

  private
  def load_votable
    klass = Object.const_get(params[:resource_type].singularize.underscore.camelcase) rescue nil
    unless klass && (@record = klass.find_by_uuid(params[:resource_id]) ||
                               klass.find(params[:resource_id]) rescue nil)
      render_404
      return false
    end
  end

  def load_vote
    load_record klass: ActsAsVotable::Vote
  end
end
