module GeoPlanet
  class Base
    class << self
      def build_url(resource_path, options = {})
        check_options_for(resource_path, options)
        
        filters       = extract_filters(options)
        matrix_params = extract_matrix_params(options)
        query_params  = extract_query_params(options)

        query_params[:appid] ||= GeoPlanet.appid # use default appid if not provided

        raise ArgumentError, "appid or q filter missing" if query_params[:appid].nil? || resource_path == 'places' && filters[:q].nil? # required

        q = ".q('#{filters[:q]}')" if filters[:q]
        type = ".type('#{filters[:type]}')" if filters[:type]
        
        query_string = q && type ? "$and(#{q},#{type})" : "#{q}#{type}"
        
        matrix_params = ";#{matrix_params.map{|k,v| "#{k}=#{v}"}.join(';')}" if matrix_params.any?
        query_params  = "?#{query_params.map{|k,v| "#{k}=#{v}"}.join('&')}"  if query_params.any?
        
        query_string += "#{matrix_params}#{query_params}"
        
        "#{GeoPlanet::API_URL}#{resource_path}#{query_string}"
      end
      
      def get(url)
        RestClient.get(url)
      rescue RestClient::RequestFailed
        raise BadRequest, "appid, q filter or format invalid"
      rescue RestClient::ResourceNotFound
        raise NotFound, "woeid or URI invalid"
      end

      protected
      def supported_options_for(resource_path)
        case resource_path
        when 'places'
          %w(q type start count lang format callback select appid)
        when /^place\/\d+\/parent$/, /^place\/\d+\/ancestors$/, /^place\/\d+$/, 'placetype'
          %w(lang format callback select appid)
        when /^place\/\d+\/belongtos$/, /^place\/\d+\/children$/, 'placetypes'
          %w(type start count lang format callback select appid)
        when /^place\/\d+\/neighbors$/, /^place\/\d+\/siblings$/
          %w(start count lang format callback select appid)
        else
          raise NotFound, "URI invalid"
        end
      end
      
      def check_options_for(resource_path, options)
        supported = supported_options_for(resource_path)
        unless options.keys.all?{|o| supported.include?(o.to_s)}
          raise ArgumentError, "invalid option(s) for #{resource_path}. Supported are: #{supported.join(', ')}. You used: #{options.keys.join(', ')}"
        end
      end
      
      def extract_filters(options)
        filters = %w(q type)
        options[:type] = options[:type].join(",") if options[:type].is_a?(Array)
        Hash[*(options.select{|k,v| filters.include?(k.to_s)}).flatten]
      end
      
      def extract_matrix_params(options)
        matrix_params = %w(start count)
        Hash[*(options.select{|k,v| matrix_params.include?(k.to_s)}).flatten]
      end
      
      def extract_query_params(options)
        query_params = %w(lang format callback select appid)
        Hash[*(options.select{|k,v| query_params.include?(k.to_s)}).flatten]
      end
    end
  end
end