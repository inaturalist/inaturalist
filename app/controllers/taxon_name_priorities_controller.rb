class TaxonNamePrioritiesController < ApplicationController
  before_action :doorkeeper_authorize!, if: ->{ authenticate_with_oauth? }
  before_action :authenticate_user!, unless: ->{ authenticated_with_oauth? }
  before_action :load_record, only: [:show, :update, :destroy]

  def create
    @taxon_name_priority = TaxonNamePriority.new( params[:taxon_name_priority] )
    @taxon_name_priority.user = current_user
    if !@taxon_name_priority.save
      flash[:error] = @taxon_name_priority.errors.full_messages.to_sentence
    end
    respond_to do |format|
      format.html do
        redirect_to( generic_edit_user_path )
      end
      format.json do
        if @taxon_name_priority.errors.any?
          render json: @taxon_name_priority.errors, status: :unprocessable_entity
        else
          render json: @taxon_name_priority.as_json
        end
      end
    end
  end

  def destroy
    if @taxon_name_priority && @taxon_name_priority.user == current_user
      @taxon_name_priority.destroy
    end
    respond_to do |format|
      format.html do
        redirect_to( generic_edit_user_path )
      end
      format.json do
        head :ok
      end
    end
  end

  def update
    # position is currently the only attribute that can be updated and has a custom update method
    if params[:taxon_name_priority][:position]
      @taxon_name_priority.update_position( params[:taxon_name_priority][:position] )
    end
    respond_to do |format|
      format.html do
        redirect_to( generic_edit_user_path )
      end
      format.json do
        if @taxon_name_priority.errors.any?
          render json: @taxon_name_priority.errors, status: :unprocessable_entity
        else
          render json: @taxon_name_priority.as_json
        end
      end
    end
  end
end
