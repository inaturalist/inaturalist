# frozen_string_literal: true

class IdSummariesDashboardController < ApplicationController
  before_action :admin_required

  def index
    @filters = {
      taxon_id: params[:taxon_id].presence,
      active_only: ActiveModel::Type::Boolean.new.cast( params[:active_only] ),
      q: params[:q].presence,
      limit: [params[:limit].to_i, 200].reject( &:zero? ).first || 50,
      offset: [params[:offset].to_i, 10_000].min
    }

    scope = TaxonIdSummary.includes( id_summaries: :id_summary_references ).order( updated_at: :desc )
    scope = scope.where( taxon_id: @filters[:taxon_id] ) if @filters[:taxon_id]
    scope = scope.where( active: true ) if @filters[:active_only]

    if @filters[:q]
      q = "%#{@filters[:q]}%"
      scope = scope.where( "taxon_name ILIKE :q OR run_name ILIKE :q OR run_description ILIKE :q", q: q )
    end

    @total = scope.count
    @taxon_summaries = scope.limit( @filters[:limit] ).offset( @filters[:offset] )
  end
end
