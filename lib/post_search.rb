# frozen_string_literal: true

class PostSearch
  # Relevance is multiplied by 1 + gauss(published_at)
  RECENCY_BOOST = { origin: "now", offset: "30d", scale: "365d", decay: 0.5 }.freeze
  QUERY_FIELDS = %w(title.standard^5 title^4 tags^3 user.login^2 user.name^2 body).freeze
  ORDERS = %w(relevance newest oldest).freeze
  PARENT_TYPES = %w(Site Project User).freeze
  DEFAULT_PER_PAGE = 30
  MAX_PER_PAGE = 200
  MAX_RESULT_WINDOW = 10_000
  POSTS_JSON_PRELOADS = [{ user: :site }, :stored_preferences, :parent].freeze
  HIGHLIGHT = {
    encoder: "html",
    fields: {
      title: { number_of_fragments: 0 },
      body: { fragment_size: 150, number_of_fragments: 1 }
    }
  }.freeze

  attr_reader :q, :tags, :parent_type, :parent_id, :user_id, :site_id, :page, :per_page, :order

  def initialize( params = {} )
    params = ( params.respond_to?( :to_unsafe_h ) ? params.to_unsafe_h : params.to_h ).with_indifferent_access
    @q = params[:q].to_s.strip.presence
    @tags = normalize_tags( params[:tags] )
    @parent_type = params[:parent_type].to_s if PARENT_TYPES.include?( params[:parent_type].to_s )
    @parent_id = positive_int( params[:parent_id] ) if @parent_type
    @user_id = positive_int( params[:user_id] )
    @site_id = positive_int( params[:site_id] )
    @page = positive_int( params[:page] ) || 1
    @per_page = [positive_int( params[:per_page] ) || DEFAULT_PER_PAGE, MAX_PER_PAGE].min
    @order = if ORDERS.include?( params[:order].to_s )
      params[:order].to_s
    else
      q ? "relevance" : "newest"
    end
  end

  def query_body
    body = {
      query: q ? scored_query : { bool: { filter: filters, must_not: exclusions } },
      sort: sort,
      from: window_exceeded? ? 0 : ( page - 1 ) * per_page,
      size: window_exceeded? ? 0 : per_page,
      _source: ["id"],
      track_total_hits: true
    }
    body[:highlight] = HIGHLIGHT if q
    body
  end

  def results
    @results ||= begin
      hits = Post.__elasticsearch__.search( query_body ).response["hits"]
      ids = hits["hits"].map {| hit | hit["_id"].to_i }
      @highlights = hits["hits"].each_with_object( {} ) do | hit, memo |
        memo[hit["_id"].to_i] = hit["highlight"] if hit["highlight"]
      end
      posts_by_id = Post.where( id: ids ).includes( POSTS_JSON_PRELOADS ).index_by( &:id )
      WillPaginate::Collection.create( page, per_page, hits["total"]["value"] ) do | pager |
        pager.replace( ids.filter_map {| id | posts_by_id[id] } )
      end
    end
  end

  # { post_id => { "title" => [html], "body" => [html] } }, escaped HTML with
  # matches wrapped in <em>
  def highlights
    results
    @highlights
  end

  private

  def scored_query
    {
      function_score: {
        query: {
          bool: {
            must: { multi_match: { query: q, fields: QUERY_FIELDS, fuzziness: "AUTO" } },
            filter: filters,
            must_not: exclusions
          }
        },
        functions: [{ weight: 1 }, { gauss: { published_at: RECENCY_BOOST } }],
        score_mode: "sum",
        boost_mode: "multiply"
      }
    }
  end

  def filters
    filters = [{ term: { published: true } }]
    filters << { term: { parent_type: parent_type } } if parent_type
    filters << { term: { parent_id: parent_id } } if parent_id
    filters << { term: { "user.id": user_id } } if user_id
    filters << { term: { site_id: site_id } } if site_id
    tags.each {| tag | filters << { term: { "tags.keyword": tag } } }
    filters
  end

  def exclusions
    [{ term: { spam: true } }, { term: { "user.spammer": true } }]
  end

  def sort
    case order
    when "oldest" then [{ published_at: "asc" }, { id: "asc" }]
    when "relevance" then ["_score", { published_at: "desc" }, { id: "desc" }]
    else [{ published_at: "desc" }, { id: "desc" }]
    end
  end

  def window_exceeded?
    page * per_page > MAX_RESULT_WINDOW
  end

  def normalize_tags( tags )
    list = tags.is_a?( Array ) ? tags : tags.to_s.split( "," )
    list.map {| tag | tag.to_s.strip.downcase }.reject( &:blank? ).uniq
  end

  def positive_int( value )
    int = Integer( value.to_s, 10, exception: false )
    int if int&.positive?
  end
end
