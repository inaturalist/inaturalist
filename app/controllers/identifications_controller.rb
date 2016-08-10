class IdentificationsController < ApplicationController
  before_action :doorkeeper_authorize!, :only => [ :create, :update, :destroy ], :if => lambda { authenticate_with_oauth? }
  before_filter :authenticate_user!, :except => [:by_login], :unless => lambda { authenticated_with_oauth? }
  before_filter :load_user_by_login, :only => [:by_login]
  load_only = [ :show, :edit, :update, :destroy ]
  before_filter :load_identification, :only => load_only
  blocks_spam :only => load_only, :instance => :identification
  before_filter :require_owner, :only => [:edit, :update, :destroy]
  cache_sweeper :comment_sweeper, :only => [:create, :update, :destroy, :agree]
  caches_action :bold, :expires_in => 6.hours, :cache_path => Proc.new {|c| 
    c.params.merge(:sequence => Digest::MD5.hexdigest(c.params[:sequence]))
  }

  def index
    @identifications = Identification.order( "id desc" ).page( params[:page] ).per_page( 100 )
    @identifications = @identifications.where( category: params[:category] ) if Identification::CATEGORIES.include?( params[:category] )
    if params[:user_id]
      if user = ( User.find_by_id( params[:user_id] ) || User.find_by_login( params[:user_id] ) )
        @identifications = @identifications.by( user )
      end
    end
    if params[:current].blank? || params[:current].yesish?
      @identifications = @identifications.current
    elsif params[:current].noish?
      @identifications = @identifications.outdated
    end
    if params[:for] == "others"
      @identifications = @identifications.joins(:observation).where( "observations.user_id != identifications.user_id" )
    end
    @identifications = @identifications.of( params[:taxon_id] ) if params[:taxon_id]
    @counts = @identifications.where("category IS NOT NULL").group(:category).count
    respond_to do |format|
      format.html { render layout: "bootstrap" }
    end
  end
    
  def show
    redirect_to observation_url(@identification.observation, :anchor => "identification-#{@identification.id}")
  end
  
  def by_login
    block_if_spammer(@selected_user) && return
    scope = @selected_user.identifications_for_others.order("identifications.id DESC")
    unless params[:on].blank?
      scope = scope.on(params[:on])
    end
    @identifications = scope.page( params[:page] ).per_page( limited_per_page ).includes(
      { observation: [ :user, :photos, { taxon: [{taxon_names: :place_taxon_names}, :photos] } ] },
      { taxon: [{taxon_names: :place_taxon_names}, :photos] },
      :user
    )
    respond_to do |format|
      format.html do
        @identifications_by_obs_id = @identifications.index_by(&:observation_id)
        @observations = @identifications.collect(&:observation)
        @other_ids = Identification.where(observation_id: @observations).where("user_id != ?", @selected_user).
          includes(:observation, :taxon)
        @other_id_stats = {}
        @other_ids.group_by(&:observation).each do |obs, ids|
          user_ident = @identifications_by_obs_id[obs.id]
          agreements = ids.select do |ident|
            ident.in_agreement_with?(user_ident)
          end
          @other_id_stats[obs.id] = {
            :num_agreements => agreements.size,
            :num_disagreements => ids.size - agreements.size
          }
        end
      end
      format.json do
        pagination_headers_for( @identifications )
        taxon_options = {
          only: [:id, :name, :rank],
          methods: [:default_name, :photo_url, :iconic_taxon_name]
        }
        render json: @identifications.as_json( include: [
          {
            taxon: taxon_options
          }, 
          {
            observation: {
              only: [:id, :species_guess],
              methods: [:iconic_taxon_name],
              include: {
                taxon: taxon_options,
                photos: {
                  only: [:id, :square_url, :thumb_url, :small_url, :medium_url, :large_url],
                  methods: [:license_code, :attribution]
                }
              }
            }
          }
        ] )
      end
    end
  end
  
  # POST identification_url
  def create
    @identification = Identification.new(params[:identification])
    @identification.user = current_user
    if @identification.taxon.blank? && params[:taxa_search_form_taxon_name]
      taxon_name = TaxonName.find_by_name(params[:taxa_search_form_taxon_name])
      @identification.taxon = taxon_name.taxon if taxon_name
    end
    
    respond_to do |format|
      duplicate_key_violation = false
      begin
        @identification.save
      rescue PG::Error, ActiveRecord::RecordNotUnique => e
        raise e unless e =~ /index_identifications_on_current/
        duplicate_key_violation = true
      end
      if @identification.valid? && duplicate_key_violation == false
        format.html do
          flash[:notice] = t(:identification_saved)
          if params[:return_to]
            return redirect_to(params[:return_to])
          end
          redirect_to @identification.observation and return
        end
        
        format.json do
          Observation.refresh_es_index
          @identification.html = view_context.render_in_format(:html, :partial => "identifications/identification")
          render :json => @identification.to_json(
            :methods => [:html], 
            :include => {
              :observation => {:methods => [:iconic_taxon_name]}
            }
          ).html_safe
        end
      else
        format.html do
          flash[:error] = t(:there_was_a_problem_saving_your_identification, :error => @identification.errors.full_messages.join(', '))
          if params[:return_to]
            return redirect_to(params[:return_to])
          end
          redirect_to @identification.observation || root_url
          return
        end
        
        format.json do
          render :status => :unprocessable_entity, :json => {:errors => @identification.errors.full_messages }
        end
      end
    end
  end
  
  def edit
  end
  
  def update
    if @identification.update_attributes(params[:identification])
      msg = t(:identification_updated)
      respond_to do |format|
        format.html do
          flash[:notice] = msg
          redirect_to @identification.observation
        end
        format.json do
          Observation.refresh_es_index
          render :json => @identification
        end
      end
    else
      msg = t(:there_was_a_problem_saving_your_identification, :error => @identification.errors.full_messages.join(', '))
      respond_to do |format|
        format.html do
          flash[:error] = msg
          redirect_to @identification.observation
        end
        format.json do
          render :status => :unprocessable_entity, :json => {:errors => @identification.errors.full_messages}
        end
      end
    end
  end
  

  # DELETE identification_url
  def destroy
    observation = @identification.observation
    @identification.update_attributes( current: false )
    respond_to do |format|
      format.html do
        flash[:notice] = t(:identification_deleted)
        redirect_to observation
      end
      format.js do
        Observation.refresh_es_index
        render :status => :ok, :json => nil
      end
      format.json do
        Observation.refresh_es_index
        render :status => :ok, :json => nil
      end
    end
  end
  
## Custom actions ############################################################

  # Agree with an identification
  def agree
    unless @observation = Observation.find_by_id(params[:observation_id])
      render_404
      return
    end
    @old_identification = @observation.identifications.by(current_user).current.last
    if @old_identification && @old_identification.taxon_id == params[:taxon_id].to_i
      @identification = @old_identification
    else
      @identification = Identification.new(
        :user => current_user,
        :taxon_id => params[:taxon_id].to_i,
        :observation_id => params[:observation_id]
      )
    end
    
    respond_to do |format|
      duplicate_key_violation = false
      begin
        @identification.save
      rescue PG::Error, ActiveRecord::RecordNotUnique => e
        raise e unless e =~ /index_identifications_on_current/
        duplicate_key_violation = true
      end
      if @identification.valid? && duplicate_key_violation == false
        format.html { agree_respond_to_html }
        format.mobile { agree_respond_to_html }
        format.json do
          @identification.html = view_context.render_in_format(:html, :partial => "identifications/identification")
          render :json => @identification.to_json(:methods => [:html])
        end
      else
        format.html { agree_respond_to_html_failure }
        format.mobile { agree_respond_to_html_failure }
        format.json do
          render :status => :unprocessable_entity, :json => {:errors => @identification.errors.full_messages }
        end
      end
    end
  end

  def bold
    url = "http://boldsystems.org/index.php/Ids_xml?db=#{params[:db]}&sequence=#{params[:sequence]}"
    xml = begin
      Nokogiri::XML(open(url))
    rescue URI::InvalidURIError => e
      "<error>#{e.message}</error>"
    end
    respond_to do |format|
      format.xml { render :xml => xml }
    end
  end
  
  private
  
  def agree_respond_to_html
    flash[:notice] = t(:identification_saved)
    if params[:return_to]
      return redirect_to(params[:return_to])
    end
    redirect_to @identification.observation
  end
  
  def agree_respond_to_html_failure
    flash[:error] = t(:there_was_a_problem_saving_your_identification, :error => @identification.errors.full_messages.join(', '))
    if params[:return_to]
      return redirect_to(params[:return_to])
    end
    redirect_to @identification.observation
  end
  
  def load_identification
    render_404 unless @identification = Identification.find_by_id(params[:id])
  end
  
  def require_owner
    unless logged_in? && @identification.user_id == current_user.id
      redirect_to_hell
    end
  end
end
