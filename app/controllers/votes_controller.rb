class VotesController < ApplicationController
  before_action :doorkeeper_authorize!, :if => lambda { authenticate_with_oauth? }
  before_filter :authenticate_user!, :unless => lambda { authenticated_with_oauth? }, except: [:by_login]
  before_filter :load_votable, except: [:by_login, :destroy]
  before_filter :load_user_by_login, only: :by_login
  before_filter :load_vote, only: [:destroy]
  before_filter :require_owner, only: [:destroy]

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
    @record.vote_by voter: current_user, vote: params[:vote], vote_scope: params[:scope]
    respond_to do |format|
      format.html do
        redirect_to @record
      end
      format.json { render json: @record.as_json(methods: [:votes]) }
    end
  end

  def unvote
    @record.unvote voter: current_user, vote: params[:vote], vote_scope: params[:scope]
    respond_to do |format|
      format.html do
        redirect_to @record
      end
      format.json { head :no_content }
    end
  end

  def for
    @users = User.
      joins("JOIN votes ON votes.voter_type = 'User' AND votes.voter_id = users.id").
      where("votes.votable_type = ? AND votes.votable_id = ?", @record.class.name, @record.id).
      where("votes.vote_scope IS NULL").
      order("users.login").
      page(params[:page]).
      per_page(100)
    respond_to do |format|
      format.html do
        render partial: 'for'
      end
    end
  end

  def by_login
    @votes = @selected_user.votes.where(vote_scope: nil).order("votes.id DESC").page(params[:page]).per_page(100)
    ActsAsVotable::Vote.preload_associations(@votes, votable: [ 
        :sounds,
        :stored_preferences,
        :quality_metrics,
        :projects,
        :flags,
        { :photos => :flags },
        { :user => :stored_preferences },
        { :taxon => [:taxon_names, :taxon_descriptions] },
        { :iconic_taxon => :taxon_descriptions }
      ])
    respond_to do |format|
      format.html
    end
  end

  private
  def load_votable
    klass = Object.const_get(params[:resource_type].singularize.underscore.camelcase) rescue nil
    unless klass && (@record = klass.find(params[:resource_id]) rescue nil)
      render_404
      return false
    end
  end

  def load_vote
    load_record klass: ActsAsVotable::Vote
  end
end
