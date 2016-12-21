class ControlledTermsController < ApplicationController

  before_filter :authenticate_user!
  before_filter :admin_required

  def index
    render
  end

  def create
    label_attrs = params[:controlled_term].delete(:controlled_term_label)
    term = ControlledTerm.new(params[:controlled_term])
    term.save
    if label_attrs && !term.errors.any?
      term.labels << ControlledTermLabel.create(label_attrs)
    end
    redirect_to :controlled_terms
  end

  def edit
    @term = ControlledTerm.find(params[:id])
  end

  def update
    if label_attrs = params[:controlled_term].delete(:controlled_term_label)
      existing = ControlledTermLabel.where(id: label_attrs[:id]).first
      if existing
        existing.update_attributes(label_attrs)
      else
        ControlledTermLabel.create(label_attrs)
      end
    end

    term = ControlledTerm.find(params[:id])
    term.update_attributes(params[:controlled_term])
    redirect_to :controlled_terms
  end

  def destroy
    term = ControlledTerm.find(params[:id])
    term.destroy
    redirect_to :controlled_terms
  end

end
