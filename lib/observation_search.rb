module ObservationSearch

  LIST_FILTER_SIZE_CAP = 5000
  SEARCH_IN_BATCHES_BATCH_SIZE = 100

  def self.included(base)
    base.extend ClassMethods
  end

  module ClassMethods
    def site_search_params(site, params = {})
      search_params = params.dup
      return search_params unless site && site.is_a?(Site)
      # don't add a site filter to project queries
      return search_params unless params[:projects].blank?
      case site.preferred_site_observations_filter
      when Site::OBSERVATIONS_FILTERS_SITE
        search_params[:site_id] = site.id if search_params[:site_id].blank?
      when Site::OBSERVATIONS_FILTERS_PLACE
        if search_params[:place_id].blank? && site.place
          search_params[:place_id] = site.place.id
        end
      when Site::OBSERVATIONS_FILTERS_BOUNDING_BOX
        if search_params[:nelat].blank? &&
            search_params[:nelng].blank? &&
            search_params[:swlat].blank? &&
            search_params[:swlng].blank?
          search_params[:nelat] = site.preferred_geo_nelat
          search_params[:nelng] = site.preferred_geo_nelng
          search_params[:swlat] = site.preferred_geo_swlat
          search_params[:swlng] = site.preferred_geo_swlng
        end
      end
      search_params
    end

    def search_in_batches(raw_params, options={}, &block)
      search_params = Observation.get_search_params(raw_params, options)
      search_params.merge!(
        min_id: raw_params[:min_id] || 1,
        per_page: raw_params[:per_page] || SEARCH_IN_BATCHES_BATCH_SIZE,
        preload: [ ],
        order_by: "id",
        order: "asc"
      )
      loop do
        batch = try_and_try_again( PG::ConnectionBad, logger: options[:logger] ) do
          Observation.page_of_results(search_params)
        end
        break if batch.size == 0
        block.call(batch)
        search_params[:min_id] = batch.last.id + 1
      end
    end

    def page_of_results(search_params={}, options={}, &block)
      Observation.elastic_query(search_params)
    end

    def get_search_params(raw_params, options={})
      raw_params = raw_params.to_hash.symbolize_keys
      if options[:site] && options[:site].is_a?(Site)
        raw_params = Observation.site_search_params(options[:site], raw_params)
      end
      if options[:current_user] && options[:current_user].is_a?(User)
        raw_params[:viewer] = options[:current_user]
      end
      search_params = Observation.query_params(raw_params)
      search_params[:viewer] = options[:current_user] if options[:current_user]
      # max 200 limit
      if search_params[:limit] && search_params[:limit].to_i > 200
        search_params[:limit] = 200
      end
      return search_params
    end

    def apply_pagination_options(params, options={})
      params ||= { }
      search_params = params.to_h.symbolize_keys
      search_params[:page] = search_params[:page].to_i
      # don't allow sub 0 page
      search_params[:page] = 1 if search_params[:page] <= 0
      if options[:user_preferences]
        search_params[:per_page] ||= options[:user_preferences]["per_page"]
      end
      # per_page defaults to limit
      if !search_params[:limit].blank?
        search_params[:per_page] = search_params[:limit]
      end
      # max 200 per_page
      if search_params[:per_page] && search_params[:per_page].to_i > 200
        search_params[:per_page] = 200
      end
      # don't allow sub 0 per_page
      search_params[:per_page] = 30 if search_params[:per_page].to_i <= 0
      search_params
    end

    # currently only used when a search included new-style projects
    # this method maps params hash that Observation.params_to_elastic_query
    # expects into the parameters that Node API obs search method expects
    def map_params_for_node_api(params)
      api_params = params.dup
      unless api_params[:has].blank?
        api_params[:has].each do |h|
          api_params[h.to_sym] = true
        end
        api_params.delete(:has)
      end
      unless api_params[:projects].blank?
        api_params[:project_id] = params[:projects].map{ |p| p.try(:id) || p }
        api_params.delete(:projects)
      end
      unless api_params[:user].blank?
        api_params[:user_id] = params[:user].id
        api_params.delete(:user)
      end
      unless api_params[:iconic_taxa_instances].blank?
        api_params[:iconic_taxa] = params[:iconic_taxa_instances].map{ |i| i ? i.id : "unknown" }
        api_params.delete(:iconic_taxa_instances)
      end
      unless api_params[:place].blank?
        api_params[:place_id] = params[:place].id
        api_params.delete(:place)
      end
      unless api_params[:viewer].blank?
        api_params[:viewer_id] = params[:viewer].id
        api_params.delete(:viewer)
      end
      if api_params[:order_by] == "observations.id"
        api_params[:order_by] = "id"
      end
      api_params[:taxon_id] = [ ]
      if !api_params[:observations_taxon].blank?
        api_params[:taxon_id] = [ api_params[:observations_taxon].id ]
        api_params.delete(:observations_taxon)
      elsif !api_params[:observations_taxa].blank?
        api_params[:taxon_id] = api_params[:observations_taxa].map(&:id)
        api_params.delete(:observations_taxa)
        api_params.delete(:observations_taxon_ids)
      end
      unless api_params[:taxon_ids].blank?
        api_params[:taxon_id] += params[:taxon_ids].map{ |id| id.split(",") }.flatten.map(&:to_i)
        api_params[:taxon_id].uniq!
        api_params.delete(:taxon_ids)
      end
      unless api_params[:min_id].blank?
        api_params[:id_above] = api_params[:min_id]
        api_params.delete(:min_id)
      end
      api_params.delete(:partial)
      api_params.delete(:controller)
      api_params.delete(:action)
      api_params.delete(:with_photos)
      api_params.delete(:with_sounds)
      api_params.delete(:_query_params_set)
      api_params.reject!{ |k,v| v == "any" || v.blank? }
      if api_params[:reviewed].blank?
        api_params.delete(:viewer_id)
      end
      if api_params[:per_page] && api_params[:per_page].to_i > 200
        api_params[:per_page] = 200
      end
      api_params
    end

    def elastic_query(params, options = {})
      elastic_params = params_to_elastic_query(params, options)
      if elastic_params.nil?
        # a dummy WillPaginate Collection is the most compatible empty result
        return WillPaginate::Collection.new(1, params[:per_page] || 30, 0)
      end
      # new projects will use the node API which has the logic
      # for search new regular and umbrella projects
      if !params[:projects].blank? &&
         params[:projects].detect{ |p| p.is_a?(Project) && p.is_new_project? }
        mapped_params = map_params_for_node_api(params)
        rsp = INatAPIService.observations(mapped_params.merge(only_id: true))
        return WillPaginate::Collection.create(rsp.page, rsp.per_page, rsp.total_results) do |pager|
          observations = Observation.where(id: rsp.results.map{ |r| r["id"] }).to_a
          pager.replace( observations )
        end
      end
      Observation.elastic_paginate(elastic_params)
    end

    def iconic_taxa_param_to_instances(iconic_taxa)
      if iconic_taxa
        # split a string of names
        if iconic_taxa.is_a? String
          iconic_taxa = iconic_taxa.split(',')
        end

        # resolve taxa entered by name
        allows_unknown = iconic_taxa.include?(nil)
        iconic_taxa = iconic_taxa.compact.map do |it|
          it = it.last if it.is_a?(Array)
          if it.is_a? Taxon
            it
          elsif it.to_i == 0
            allows_unknown = true if it.to_s.downcase == "unknown"
            Taxon::ICONIC_TAXA_BY_NAME[it]
          else
            Taxon::ICONIC_TAXA_BY_ID[it]
          end
        end.uniq.compact
        iconic_taxa << nil if allows_unknown
        iconic_taxa
      end
    end

    def elastic_taxon_leaf_ids(elastic_params = {})
      distinct_taxa = Observation.elastic_search(elastic_params.merge(size: 0,
        aggregate: { species: { "taxon.id": 150000 } })).response.aggregations
      @taxa = Taxon.where(id: distinct_taxa.species.buckets.map{ |b| b["key"] }).
        select(:id, :ancestry)
      ancestors = { }
      @taxa.each do |t|
        t.ancestor_ids.each do |aid|
          ancestors[aid] ||= 0
          ancestors[aid] += 1
        end
      end
      @taxa.select{ |t| !ancestors[t.id] }.map(&:id)
    end

    def elastic_taxon_leaf_counts(elastic_params = {})
      distinct_taxa = Observation.elastic_search(elastic_params.merge(size: 0,
        aggregate: { species: { "taxon.id": 150000 } })).response.aggregations
      counts = Hash[distinct_taxa.species.buckets.map{ |b| [ b["key"], b["doc_count"] ] }]
      @taxa = Taxon.where(id: counts.keys ).select(:id, :ancestry)
      ancestors = { }
      @taxa.each do |t|
        t.ancestor_ids.each do |aid|
          ancestors[aid] ||= 0
          ancestors[aid] += 1
        end
      end
      counts.reject{|k,v| ancestors[k] }
    end

    # Takes a hash of query params like you'd get from an ActionController and
    # normalizes them for use in our search methods like query (database) or
    # elastic_query (ES)
    def query_params(params)
      p = params.to_hash.symbolize_keys
      unless p[:apply_project_rules_for].blank?
        if proj = Project.find_by_id(p[:apply_project_rules_for])
          p.merge!(proj.observations_url_params(extended: true))
        end
        p.delete(:apply_project_rules_for)
      end
      unless p[:list_id].blank?
        list = List.find_by_id(p[:list_id])
        p.delete(:list_id)
        p[:taxon_ids] ||= [ ]
        if list && list.taxon_ids.any?
          p[:taxon_ids] += list.taxon_ids
        else
          # the list has no taxa, so no results. Set this
          # params so the query returns nothing
          p[:empty_set] = true
        end
      end
      if p[:swlat].blank? && p[:swlng].blank? && p[:nelat].blank? && p[:nelng].blank? && p[:BBOX]
        p[:swlng], p[:swlat], p[:nelng], p[:nelat] = p[:BBOX].split(',')
      end
      unless p[:place_id].blank?
        p[:place] = begin
          Place.find(p[:place_id])
        rescue ActiveRecord::RecordNotFound
          nil
        end
        p[:place_id] = p[:place].id if p[:place] && p[:place].is_a?( Place )
      end
      unless p[:not_in_place].blank?
        not_in_place_record = begin
          Place.find( p[:not_in_place] )
        rescue ActiveRecord::RecordNotFound
          nil
        end
        p[:not_in_place] = not_in_place_record&.id if not_in_place_record.is_a?( Place )
        p[:not_in_place_record] = not_in_place_record
      end
      p[:search_on] = nil unless Observation::FIELDS_TO_SEARCH_ON.include?(p[:search_on])
      # iconic_taxa
      if p[:iconic_taxa]
        p[:iconic_taxa_instances] = iconic_taxa_param_to_instances(p[:iconic_taxa])
      end
      if !p[:taxon_id].blank?
        p[:observations_taxon] = Taxon.find_by_id(p[:taxon_id].to_i)
      elsif !p[:taxon_name].blank?
        begin
          p[:observations_taxon] = Taxon.single_taxon_for_name(p[:taxon_name], iconic_taxa: p[:iconic_taxa_instances])
        rescue ActiveRecord::StatementInvalid => e
          raise e unless e.message =~ /invalid byte sequence/
          taxon_name_conditions[1] = p[:taxon_name].encode('UTF-8')
          p[:observations_taxon] = TaxonName.where(taxon_name_conditions).joins(includes).first.try(:taxon)
        end
        if !p[:observations_taxon]
          p.delete(:taxon_name)
        end
      end
      if p[:taxon_ids] == [""]
        p[:taxon_ids] = nil
      end
      if !p[:observations_taxon] && !p[:taxon_ids].blank?
        p[:observations_taxon_ids] = [p[:taxon_ids]].flatten.join(',').split(',').map(&:to_i)
        p[:observations_taxa] = Taxon.where(id: p[:observations_taxon_ids]).limit(100)
      end

      unless p[:without_taxon_id].blank?
        p[:without_observations_taxon] = Taxon.find_by_id( p[:without_taxon_id].to_i )
      end

      if p[:has]
        p[:has] = p[:has].split(',') if p[:has].is_a?(String)
        p[:id_please] = true if p[:has].include?('id_please')
        p[:with_photos] = true if p[:has].include?('photos')
        p[:with_sounds] = true if p[:has].include?('sounds')
        p[:with_geo] = true if p[:has].include?('geo')
      end

      p[:captive] = p[:captive].yesish? unless p[:captive].blank?

      if p[:skip_order]
        p.delete(:order)
        p.delete(:order_by)
      else
        p[:order_by] = "created_at" if p[:order_by] == "observations.id"
        if ObservationsController::ORDER_BY_FIELDS.include?(p[:order_by].to_s)
          p[:order] = if %w(asc desc).include?(p[:order].to_s.downcase)
            p[:order]
          else
            'desc'
          end
        else
          p[:order_by] = "observations.id"
          p[:order] = "desc"
        end
      end

      # date
      date_pieces = [p[:year], p[:month], p[:day]]
      unless date_pieces.map{|d| (d.blank? || d.is_a?(Array)) ? nil : d}.compact.blank?
        p[:on] = date_pieces.join('-')
      end
      if p[:on].to_s =~ /^\d{4}/
        p[:observed_on] = p[:on]
        if d = Observation.split_date(p[:observed_on])
          p[:observed_on_year], p[:observed_on_month], p[:observed_on_day] = [ d[:year], d[:month], d[:day] ]
        end
      end
      p[:observed_on_year] ||= p[:year].to_i unless p[:year].blank?
      p[:observed_on_month] ||= p[:month].to_i unless p[:month].blank? || p[:month].is_a?(Array)
      p[:observed_on_day] ||= p[:day].to_i unless p[:day].blank?

      # observation fields
      ofv_params = p.select{|k,v| k =~ /^field\:/}
      unless ofv_params.blank?
        p[:ofv_params] = {}
        ofv_params.each do |k,v|
          p[:ofv_params][k] = {
            :normalized_name => ObservationField.normalize_name(k.to_s),
            :value => v
          }
        end
        observation_fields = ObservationField.where("lower(name) IN (?)", p[:ofv_params].map{|k,v| v[:normalized_name]})
        p[:ofv_params].each do |k,v|
          v[:observation_field] = observation_fields.detect do |of|
            v[:normalized_name] == ObservationField.normalize_name(of.name)
          end
        end
        p[:ofv_params].delete_if{|k,v| v[:observation_field].blank?}
      end

      p[:user_id] = p[:user_id] || p[:user]

      # Handle multiple users in user_id
      users = [p[:user_id].to_s.split( "," )].flatten.map do | user_id |
        candidate = user_id.to_s.strip
        User.find_by_id( candidate ) || User.find_by_login( candidate )
      end.compact
      p[:user_id] = users.blank? ? nil : users.map(&:id)
      p[:user_id] = p[:user_id].first if p[:user_id].is_a?( Array ) && p[:user_id].size == 1

      unless p[:user_id].blank? || p[:user_id].is_a?(Array)
        p[:user] = User.find_by_id(p[:user_id])
        p[:user] ||= User.find_by_login(p[:user_id])
      end
      if p[:user].blank? && !p[:login].blank?
        p[:user] ||= User.find_by_login(p[:login])
      end

      unless p[:ident_user_id].blank?
        ident_users = p[:ident_user_id].is_a?( Array ) ?
          p[:ident_user_id] : [p[:ident_user_id].to_s.split( "," )].flatten
        ident_user_ids = []
        ident_users.each do | id_or_login |
          id_or_login = id_or_login.strip
          ident_user = User.find_by_id( id_or_login )
          ident_user ||= User.find_by_login( id_or_login )
          ident_user_ids << ident_user.id if ident_user
        end
        p[:ident_user_id] = ident_user_ids.join( "," )
      end

      unless p[:projects].blank?
        project_ids = [p[:projects]].flatten
        p[:projects] = Project.find(Project.slugs_to_ids(project_ids))
        p[:projects] = p[:projects].compact
        if p[:projects].blank?
          project_ids.each do |project_id|
            p[:projects] += Project.find(Project.slugs_to_ids(project_id))
          end
          p[:projects] = p[:projects].flatten.compact
        end
      end

      if p[:pcid] && p[:pcid] != 'any'
        p[:pcid] = p[:pcid].yesish?
      end

      unless p[:not_in_project].blank?
        p[:not_in_project] = Project.find(p[:not_in_project]) rescue nil
      end

      p[:rank] = p[:rank] if Taxon::VISIBLE_RANKS.include?(p[:rank])
      p[:hrank] = p[:hrank] if Taxon::VISIBLE_RANKS.include?(p[:hrank])
      p[:lrank] = p[:lrank] if Taxon::VISIBLE_RANKS.include?(p[:lrank])

      p.each do |k,v|
        p[k] = nil if v.is_a?(String) && v.blank?
      end

      p[:_query_params_set] = true
      p
    end

    #
    # Uses scopes to perform a conditional search.
    # May be worth looking into squirrel or some other rails friendly search add on
    #
    def query(params = {})
      scope = self
      viewer = params[:viewer].is_a?(User) ? params[:viewer].id : params[:viewer]

      place_ids = [ ]
      if params[:place_id].is_a?(Array)
        place_ids = params[:place_id]
      elsif params[:place_id].to_i > 0
        place_ids << params[:place_id]
      elsif !params[:place_id].blank? && p = Place.find(params[:place_id])
        place_ids << p.id
      end

      # support bounding box queries
      if (!params[:swlat].blank? && !params[:swlng].blank? &&
          !params[:nelat].blank? && !params[:nelng].blank?)
        scope = scope.in_bounding_box(params[:swlat], params[:swlng], params[:nelat], params[:nelng],
          :private => (viewer && viewer == params[:user_id]))
      elsif !params[:BBOX].blank?
        swlng, swlat, nelng, nelat = params[:BBOX].split(',')
        scope = scope.in_bounding_box(swlat, swlng, nelat, nelng)
      elsif params[:lat] && params[:lng]
        scope = scope.near_point(params[:lat], params[:lng], params[:radius])
      end

      # has (boolean) selectors
      if params[:has]
        params[:has] = params[:has].split(',') if params[:has].is_a? String
        params[:has].select{|s| %w(geo id_please photos sounds).include?(s)}.each do |prop|
          scope = case prop
            when 'geo' then scope.has_geo
            when 'id_please' then scope.has_id_please
            when 'photos' then scope.has_photos
            when 'sounds' then scope.has_sounds
          end
        end
      end
      if params[:identifications] && params[:identifications] != "any"
        scope = scope.identifications(params[:identifications])
      end
      scope = scope.has_iconic_taxa(params[:iconic_taxa_instances]) if params[:iconic_taxa_instances]
      scope = scope.order_by("#{params[:order_by]} #{params[:order]}") if params[:order_by]

      quality_grades = params[:quality_grade].to_s.split(',')
      if (quality_grades & Observation::QUALITY_GRADES).size > 0
        scope = scope.has_quality_grade( params[:quality_grade] )
      end

      if taxon = params[:taxon]
        scope = scope.of(taxon.is_a?(Taxon) ? taxon : taxon.to_i)
      elsif !params[:taxon_id].blank?
        scope = scope.of(params[:taxon_id].to_i)
      elsif !params[:taxon_name].blank?
        scope = scope.of(Taxon.single_taxon_for_name(params[:taxon_name],
          iconic_taxa: params[:iconic_taxa_instances]))
      elsif !params[:taxon_ids].blank?
        taxon_ids = params[:taxon_ids].map(&:to_i)
        if params[:taxon_ids].size == 1
          scope = scope.of(taxon_ids.first)
        else
          taxa = Taxon::ICONIC_TAXA.select{|t| taxon_ids.include?(t.id) }
          if taxa.size == taxon_ids.size
            scope = scope.has_iconic_taxa(taxon_ids)
          end
        end
      end
      if params[:on]
        scope = scope.on(params[:on])
      elsif params[:year] || params[:month] || params[:day]
        date_pieces = [params[:year], params[:month], params[:day]]
        unless date_pieces.map{|d| d.blank? ? nil : d}.compact.blank?
          scope = scope.on(date_pieces.join('-'))
        end
      end
      scope = scope.by(params[:user_id]) if params[:user_id]
      scope = scope.in_projects(params[:projects]) if params[:projects]
      scope = scope.in_places(place_ids) unless place_ids.empty?
      scope = scope.created_on(params[:created_on]) if params[:created_on]
      scope = scope.in_range if params[:out_of_range] == 'false'
      scope = scope.license(params[:license]) unless params[:license].blank?
      scope = scope.photo_license(params[:photo_license]) unless params[:photo_license].blank?
      scope = scope.where(:captive => true) if params[:captive].yesish?
      if params[:mappable].yesish?
        scope = scope.where(:mappable => true)
      elsif params[:mappable] && params[:mappable].noish?
        scope = scope.where(:mappable => false)
      end
      if [false, 'false', 'f', 'no', 'n', 0, '0'].include?(params[:captive])
        scope = scope.where("observations.captive = ? OR observations.captive IS NULL", false)
      end
      unless params[:ofv_params].blank?
        params[:ofv_params].each do |k,v|
          scope = scope.has_observation_field(v[:observation_field], v[:value])
        end
      end

      # TODO change this to use the Site model
      if !params[:site].blank? && params[:site] != 'any'
        uri = params[:site]
        uri = "http://#{uri}" unless uri =~ /^http\:\/\//
        scope = scope.where("observations.uri LIKE ?", "#{uri}%")
      end

      if !params[:site_id].blank? && site = Site.find_by_id(params[:site_id])
        scope = scope.where("observations.site_id = ?", site)
      end

      if !params[:h1].blank? && !params[:h2].blank?
        scope = scope.between_hours(params[:h1], params[:h2])
      end

      if !params[:m1].blank? && !params[:m2].blank?
        scope = scope.between_months(params[:m1], params[:m2])
      end

      if !params[:d1].blank? && !params[:d2].blank?
        scope = scope.between_dates(params[:d1], params[:d2])
      end

      unless params[:week].blank?
        scope = scope.week(params[:week])
      end

      if !params[:cs].blank?
        scope = scope.joins(:taxon => :conservation_statuses).where("conservation_statuses.status IN (?)", [params[:cs]].flatten)
        scope = if place_ids.empty?
          scope.where("conservation_statuses.place_id IS NULL")
        else
          scope.where("conservation_statuses.place_id IN (?) OR conservation_statuses.place_id IS NULL", place_ids.join(","))
        end
      end

      if !params[:csi].blank?
        iucn_equivs = [params[:csi]].flatten.map{|v| Taxon::IUCN_CODE_VALUES[v.upcase]}.compact.uniq
        scope = scope.joins(:taxon => :conservation_statuses).where("conservation_statuses.iucn IN (?)", iucn_equivs)
        scope = if place_ids.empty?
          scope.where("conservation_statuses.place_id IS NULL")
        else
          scope.where("conservation_statuses.place_id IN (?) OR conservation_statuses.place_id IS NULL", place_ids.join(","))
        end
      end

      if !params[:csa].blank?
        scope = scope.joins(:taxon => :conservation_statuses).where("conservation_statuses.authority = ?", params[:csa])
        scope = if place_ids.empty?
          scope.where("conservation_statuses.place_id IS NULL")
        else
          scope.where("conservation_statuses.place_id IN (?) OR conservation_statuses.place_id IS NULL", place_ids.join(","))
        end
      end

      establishment_means = params[:establishment_means] || params[:em]
      if !place_ids.empty? && !establishment_means.blank?
        scope = scope.
          joins("JOIN listed_taxa ON listed_taxa.taxon_id = observations.taxon_id").
          where("listed_taxa.place_id IN (?)", place_ids.join(","))
        scope = case establishment_means
        when ListedTaxon::NATIVE
          scope.where("listed_taxa.establishment_means IN (?)", ListedTaxon::NATIVE_EQUIVALENTS)
        when ListedTaxon::INTRODUCED
          scope.where("listed_taxa.establishment_means IN (?)", ListedTaxon::INTRODUCED_EQUIVALENTS)
        else
          scope.where("listed_taxa.establishment_means = ?", establishment_means)
        end
      end

      if !params[:pcid].nil? && params[:pcid] != "any"
        scope = if params[:pcid].yesish?
          scope.joins(:project_observations).where("project_observations.curator_identification_id IS NOT NULL")
        else
          scope.joins(:project_observations).where("project_observations.curator_identification_id IS NULL")
        end
      end

      unless params[:geoprivacy].blank?
        scope = case params[:geoprivacy]
        when "any"
          # do nothing
        when OPEN
          scope.where("geoprivacy IS NULL")
        when "obscured_private"
          scope.where("geoprivacy IN (?)", Observation::GEOPRIVACIES)
        else
          scope.where(:geoprivacy => params[:geoprivacy])
        end
      end

      rank = params[:rank].to_s.downcase
      if Taxon::VISIBLE_RANKS.include?(rank)
        scope = scope.joins(:taxon).where("taxa.rank = ?", rank)
      end

      high_rank = params[:hrank]
      if Taxon::VISIBLE_RANKS.include?(high_rank)
        rank_level = Taxon::RANK_LEVELS[high_rank]
        scope = scope.joins(:taxon).where("taxa.rank_level <= ?", rank_level)
      end

      low_rank = params[:lrank]
      if Taxon::VISIBLE_RANKS.include?(low_rank)
        rank_level = Taxon::RANK_LEVELS[low_rank]
        scope = scope.joins(:taxon).where("taxa.rank_level >= ?", rank_level)
      end

      unless params[:updated_since].blank?
        if params[:updated_since].is_a?( String )
          params[:updated_since] = params[:updated_since].gsub( /\s(\d+\:\d+)$/, "+\\1" )
        end
        if timestamp = Chronic.parse(params[:updated_since])
          if params[:aggregation_user_ids].blank?
            scope = scope.where("observations.updated_at > ?", timestamp)
          else
            scope = scope.where("observations.updated_at > ? OR observations.user_id IN (?)",
              timestamp, params[:aggregation_user_ids])
          end
        else
          scope = scope.where("1 = 2")
        end
      end

      unless params[:q].blank?
        scope = scope.dbsearch(params[:q])
      end

      if list = List.find_by_id(params[:list_id])
        if list.listed_taxa.count <= LIST_FILTER_SIZE_CAP
          scope = scope.joins("JOIN listed_taxa ON listed_taxa.taxon_id = observations.taxon_id").
            where("listed_taxa.list_id = #{list.id}")
        end
      end

      if params[:identified].yesish?
        scope = scope.has_taxon
      elsif params[:identified].noish?
        scope = scope.where("taxon_id IS NULL")
      end

      if viewer
        if params[:reviewed] === "true"
          scope = scope.reviewed_by(viewer)
        elsif params[:reviewed] === "false"
          scope = scope.not_reviewed_by(viewer)
        end
      end

      scope = scope.not_flagged_as_spam if params[:filter_spam]
      scope = scope.where("observations.id >= ?", params[:min_id]) unless params[:min_id].blank?
      # return the scope, we can use this for will_paginate calls like:
      # Observation.query(params).paginate()
      scope
    end

    def elastic_user_observation_counts(elastic_params, limit = 500)
      user_counts = Observation.elastic_search(elastic_params.merge(size: 0, aggregate: {
        distinct_users: { cardinality: { field: "user.id", precision_threshold: 10000 } },
        user_observations: { "user.id": limit }
      })).response.aggregations
      { counts: user_counts.user_observations.buckets.
          map{ |b| { "user_id" => b["key"], "count_all" => b["doc_count"] } },
        total: user_counts.distinct_users.value }
    end

    def elastic_user_taxon_counts(elastic_params, options = {})
      options[:limit] ||= 500
      aggregation_user_limit = 10000
      elastic_params[:filters] ||= [ ]
      elastic_params[:filters] << { range: {
        "taxon.rank_level" => { lte: Taxon::RANK_LEVELS["species"] } } }
      # We've started running into memory problems with ES not being able to
      # handle some aggregates on a large scale. We will query for users in
      # batches of 10,000, so if there are fewer than that we can query now.
      if( options[:batch] == false ||
          (options[:count_users] && options[:count_users] <= aggregation_user_limit) )
        return elastic_user_taxon_counts_batch(elastic_params, options)
      end
      # fetch a list of every user_id whose observations match the search
      user_counts = Observation.elastic_search(elastic_params.merge(size: 0, aggregate: {
        user_observations: { "user.id": 100000 }
      })).response.aggregations
      user_ids = user_counts.user_observations.buckets.map{ |b| b["key"] }
      counts = [ ]
      # in batches, search ES with the original query filtered by the batch IDs
      user_ids.each_slice(aggregation_user_limit) do |batch_user_ids|
        filters = elastic_params[:filters] + [
          { terms: { "user.id" => batch_user_ids } } ]
        counts += elastic_user_taxon_counts_batch(elastic_params.merge(filters: filters), options)
      end
      # sort by count descending and return the top `limit`
      counts.sort_by{ |b| b["count_all"] }.reverse[0...options[:limit]]
    end

    def elastic_user_taxon_counts_batch(elastic_params, options = {})
      options[:limit] ||= 500
      aggregation = {
        user_taxa: {
          terms: {
            field: "user.id", size: options[:limit], order: { "distinct_taxa": :desc }
          },
          aggs: {
            distinct_taxa: {
              cardinality: { field: "taxon.id", precision_threshold: 100 }
            }
          }
        }
      }
      if ( ( options[:limit] * 1.5 ) + 10 ) < 200
        # attempting to account for inaccurate counts for queries with a small size
        # see https://www.elastic.co/guide/en/elasticsearch/reference/current/search-aggregations-bucket-terms-aggregation.html#search-aggregations-bucket-terms-aggregation-shard-size
        aggregation[:user_taxa][:terms][:shard_size] = 200
      end
      species_counts = Observation.elastic_search( elastic_params.merge( size: 0, aggregate: aggregation ) ).response.aggregations
      species_counts.user_taxa.buckets.
        map{ |b| { "user_id" => b["key"], "count_all" => b["distinct_taxa"]["value"] } }
    end

  end

end
