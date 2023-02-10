class ControlledTermLabelsController < ApplicationController

  before_action :authenticate_user!
  before_action :admin_required

  def create
    label = ControlledTermLabel.new(params[:controlled_term_label])
    label.save
    redirect_to label.controlled_term ?
      edit_controlled_term_path(label.controlled_term) : :controlled_terms
  end

  def update
    label = ControlledTermLabel.find(params[:id])
    label.update(params[:controlled_term_label])
    redirect_to label.controlled_term ?
      edit_controlled_term_path(label.controlled_term) : :controlled_terms
  end

  def destroy
    label = ControlledTermLabel.find(params[:id])
    label.destroy
    redirect_to label.controlled_term ?
      edit_controlled_term_path(label.controlled_term) : :controlled_terms
  end

end
