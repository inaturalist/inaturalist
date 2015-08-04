module ObservationSearch

  def self.included(base)
    base.extend ClassMethods
  end

  module ClassMethods
    def site_search_params(site, params = {})
      search_params = params.dup
      return search_params unless site && site.is_a?(Site)
      case site.preferred_site_observations_filter
      when Site::OBSERVATIONS_FILTERS_SITE
        search_params[:site_id] = site.id if search_params[:site_id].blank?
      when Site::OBSERVATIONS_FILTERS_PLACE
        search_params[:place] = site.place if search_params[:place_id].blank?
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
      search_params.merge!({ page: 1, per_page: 500, preload: [ ],
        order_by: "id", order: "asc" })
      scope = Observation.get_search_scope_or_elastic_results(search_params)
      if scope.is_a?(ActiveRecord::Relation)
        scope.find_in_batches(batch_size: search_params[:per_page]) do |batch|
          block.call(batch)
        end
      elsif scope.is_a?(WillPaginate::Collection)
        block.call(scope)
        total_pages = (scope.total_entries / search_params[:per_page].to_f).ceil
        while search_params[:page] < total_pages
          search_params[:page] += 1
          block.call(Observation.get_search_scope_or_elastic_results(search_params))
        end
      end
    end

    def page_of_results(search_params={}, options={}, &block)
      scope = Observation.get_search_scope_or_elastic_results(search_params)
      if scope.is_a?(ActiveRecord::Relation)
        return scope.paginate(page: search_params[:page], per_page: search_params[:per_page]).
          order(nil)
      elsif scope.is_a?(WillPaginate::Collection)
        return scope
      end
    end

    def get_search_params(raw_params, options={})
      raw_params = raw_params.clone.symbolize_keys
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
      search_params = params.clone.symbolize_keys
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

    def get_search_scope_or_elastic_results(search_params)
      unless Observation.able_to_use_elasticsearch?(search_params)
        # if we have one of these non-elastic attributes,
        # then default to searching PostgreSQL via ActiveRecord
        return Observation.query(search_params)
      end
      Observation.elastic_query(search_params)
    end

    def able_to_use_elasticsearch?(search_params)
      # there are some attributes which have not yet been added to the
      # elasticsearch index, or we have decided not to put in the index
      # because it would be more work to maintain than it would save
      # when searching. Remove empty values before checking
      return false if search_params[:rank] == "leaves"
      ! ((Observation::NON_ELASTIC_ATTRIBUTES.map(&:to_sym) &
        search_params.reject{ |k,v| (v != false && v.blank?) || v == "any" }.keys).any?)
    end

    def elastic_query(params, options = {})
      elastic_params = params_to_elastic_query(params, options)
      if elastic_params.nil?
        # a dummy WillPaginate Collection is the most compatible empty result
        return WillPaginate::Collection.new(1, 30, 0)
      end
      Observation.elastic_paginate(elastic_params)
    end

    def query_params(params)
      p = params.clone.symbolize_keys
      if p[:swlat].blank? && p[:swlng].blank? && p[:nelat].blank? && p[:nelng].blank? && p[:BBOX]
        p[:swlng], p[:swlat], p[:nelng], p[:nelat] = p[:BBOX].split(',')
      end
      unless p[:place_id].blank?
        p[:place] = begin
          Place.find(p[:place_id])
        rescue ActiveRecord::RecordNotFound
          nil
        end
      end
      p[:q] = sanitize_query(p[:q]) unless p[:q].blank?
      p[:search_on] = nil unless Observation::FIELDS_TO_SEARCH_ON.include?(p[:search_on])
      # iconic_taxa
      if p[:iconic_taxa]
        # split a string of names
        if p[:iconic_taxa].is_a? String
          p[:iconic_taxa] = p[:iconic_taxa].split(',')
        end

        # resolve taxa entered by name
        allows_unknown = p[:iconic_taxa].include?(nil)
        p[:iconic_taxa] = p[:iconic_taxa].compact.map do |it|
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
        p[:iconic_taxa] << nil if allows_unknown
      end
      if !p[:taxon_id].blank?
        p[:observations_taxon] = Taxon.find_by_id(p[:taxon_id].to_i)
      elsif !p[:taxon_name].blank?
        begin
          p[:observations_taxon] = Taxon.single_taxon_for_name(p[:taxon_name], iconic_taxa: p[:iconic_taxa])
        rescue ActiveRecord::StatementInvalid => e
          raise e unless e.message =~ /invalid byte sequence/
          taxon_name_conditions[1] = p[:taxon_name].encode('UTF-8')
          p[:observations_taxon] = TaxonName.where(taxon_name_conditions).joins(includes).first.try(:taxon)
        end
      end
      if !p[:observations_taxon] && !p[:taxon_ids].blank?
        p[:observations_taxon_ids] = p[:taxon_ids]
        p[:observations_taxa] = Taxon.where(id: p[:observations_taxon_ids]).limit(100)
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
      unless date_pieces.map{|d| d.blank? ? nil : d}.compact.blank?
        p[:on] = date_pieces.join('-')
      end
      if p[:on].to_s =~ /^\d{4}/
        p[:observed_on] = p[:on]
        if d = Observation.split_date(p[:observed_on])
          p[:observed_on_year], p[:observed_on_month], p[:observed_on_day] = [ d[:year], d[:month], d[:day] ]
        end
      end
      p[:observed_on_year] ||= p[:year].to_i unless p[:year].blank?
      p[:observed_on_month] ||= p[:month].to_i unless p[:month].blank?
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

      unless p[:user_id].blank?
        p[:user] = User.find_by_id(p[:user_id])
        p[:user] ||= User.find_by_login(p[:user_id])
      end
      if p[:user].blank? && !p[:login].blank?
        p[:user] ||= User.find_by_login(p[:login])
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

      place_id = if params[:place_id].to_i > 0
        params[:place_id]
      elsif !params[:place_id].blank?
        Place.find(params[:place_id]).try(:id) rescue 0
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
      scope = scope.has_iconic_taxa(params[:iconic_taxa]) if params[:iconic_taxa]
      scope = scope.order_by("#{params[:order_by]} #{params[:order]}") if params[:order_by]

      quality_grades = params[:quality_grade].to_s.split(',')
      # if Observation::QUALITY_GRADES.include?(params[:quality_grade])
      if (quality_grades & Observation::QUALITY_GRADES).size > 0
        scope = scope.has_quality_grade( params[:quality_grade] )
      end

      if taxon = params[:taxon]
        scope = scope.of(taxon.is_a?(Taxon) ? taxon : taxon.to_i)
      elsif !params[:taxon_id].blank?
        scope = scope.of(params[:taxon_id].to_i)
      elsif !params[:taxon_name].blank?
        scope = scope.of(Taxon.single_taxon_for_name(params[:taxon_name], :iconic_taxa => params[:iconic_taxa]))
      elsif !params[:taxon_ids].blank?
        taxon_ids = params[:taxon_ids].map(&:to_i)
        if params[:taxon_ids].size == 1
          scope = scope.of(taxon_ids.first)
        else
          taxa = Taxon::ICONIC_TAXA.select{|t| taxon_ids.include?(t.id)}
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
      scope = scope.in_place(place_id) unless params[:place_id].blank?
      scope = scope.created_on(params[:created_on]) if params[:created_on]
      scope = scope.out_of_range if params[:out_of_range] == 'true'
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
        scope = if place_id.blank?
          scope.where("conservation_statuses.place_id IS NULL")
        else
          scope.where("conservation_statuses.place_id = ? OR conservation_statuses.place_id IS NULL", place_id)
        end
      end

      if !params[:csi].blank?
        iucn_equivs = [params[:csi]].flatten.map{|v| Taxon::IUCN_CODE_VALUES[v.upcase]}.compact.uniq
        scope = scope.joins(:taxon => :conservation_statuses).where("conservation_statuses.iucn IN (?)", iucn_equivs)
        scope = if place_id.blank?
          scope.where("conservation_statuses.place_id IS NULL")
        else
          scope.where("conservation_statuses.place_id = ? OR conservation_statuses.place_id IS NULL", place_id)
        end
      end

      if !params[:csa].blank?
        scope = scope.joins(:taxon => :conservation_statuses).where("conservation_statuses.authority = ?", params[:csa])
        scope = if place_id.blank?
          scope.where("conservation_statuses.place_id IS NULL")
        else
          scope.where("conservation_statuses.place_id = ? OR conservation_statuses.place_id IS NULL", place_id)
        end
      end

      establishment_means = params[:establishment_means] || params[:em]
      if !place_id.blank? && !establishment_means.blank?
        scope = scope.
          joins("JOIN listed_taxa ON listed_taxa.taxon_id = observations.taxon_id").
          where("listed_taxa.place_id = ?", place_id)
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
        if timestamp = Chronic.parse(params[:updated_since])
          scope = scope.where("observations.updated_at > ?", timestamp)
        else
          scope = scope.where("1 = 2")
        end
      end

      unless params[:q].blank?
        scope = scope.dbsearch(params[:q])
      end

      if list = List.find_by_id(params[:list_id])
        if list.listed_taxa.count <= 2000
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
      # return the scope, we can use this for will_paginate calls like:
      # Observation.query(params).paginate()
      scope
    end
  end

end
