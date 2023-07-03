class GeoModelController < ApplicationController
  before_action :authenticate_user!
  before_action :admin_required

  def index
    respond_to do | format |
      format.html do
        render layout: "bootstrap", action: "index"
      end

      format.json do
        params[:page] = params[:page].to_i
        if !params[:page] || !params[:page].is_a?( Integer ) || params[:page] < 1
          params[:page] = 1
        end

        sort_column = case params[:order_by]
        when "id" then "taxon_id"
        when "prauc" then "prauc"
        when "precision" then "precision"
        when "recall" then "recall"
        when "f1" then "f1"
        when "threshold" then "threshold"
        else "taxa.name"
        end
        sort_order = case params[:order]
        when "desc" then "desc"
        else "asc"
        end
        per_page = 1000
        geo_model_taxa = GeoModelTaxon.
          joins( :taxon ).includes( :taxon ).limit( per_page )
        geo_model_taxa = geo_model_taxa.order( "#{sort_column} #{sort_order} NULLS LAST" )
        render json: geo_model_taxa.map{ |gmt|
          {
            taxon_id: gmt.taxon_id,
            prauc: gmt.prauc,
            precision: gmt.precision,
            recall: gmt.recall,
            f1: gmt.f1,
            threshold: gmt.threshold,
            name: gmt.taxon.name
          }
        }
      end
    end
  end

  def explain
    @taxon = Taxon.find( params[:id] )
    site_place = @site && @site.place
    user_place = current_user && current_user.place
    preferred_place = user_place || site_place

    @raw_env_data = JSON.parse( File.read(
      File.join( CONFIG.geo_model_data_path, "tf_env_maps/#{@taxon.id}.json" )
    ) )
    @presence_absence = JSON.parse( File.read(
      File.join( CONFIG.geo_model_data_path, "tf_env_presence_maps/#{@taxon.id}.json" )
    ) )
    taxon_range_data_path = File.join(
      CONFIG.geo_model_data_path, "taxon_range_maps/#{@taxon.id}.json"
    )
    @taxon_range = File.exist?( taxon_range_data_path ) ?
      JSON.parse( File.read( taxon_range_data_path ) ) : { }
    api_url = "/taxa/#{@taxon.id}?preferred_place_id=#{preferred_place.try(:id)}&locale=#{I18n.locale}"
    @node_taxon_json = INatAPIService.get_json( api_url )
    @geo_model_taxon = GeoModelTaxon.where( taxon_id: @taxon ).first
    render layout: "bootstrap", action: "explain"
  end

end
