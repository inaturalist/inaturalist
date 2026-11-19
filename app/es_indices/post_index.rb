# frozen_string_literal: true

class Post < ApplicationRecord
  acts_as_elastic_model

  DEFAULT_ES_BATCH_SIZE = 500
  INDEXED_BODY_MAX_LENGTH = 100_000
  BODY_EXCERPT_LENGTH = 500

  attr_accessor :indexed_comments_count

  scope :load_for_index, -> { includes( :flags, :tags, :parent, :user ) }

  # The body is stored on its own and kept out of _source: highlighting reads
  # the stored field, and _source reads stay small.
  settings index: { number_of_shards: 1, analysis: ElasticModel::ANALYSIS } do
    mappings( dynamic: true, _source: { excludes: ["body"] } ) do
      indexes :body, analyzer: "ascii_snowball_analyzer", store: true
      indexes :body_excerpt, type: "text", index: false
      indexes :comments_count, type: "integer"
      indexes :id, type: "integer" do
        indexes :keyword, type: "keyword"
      end
      indexes :locale, type: "keyword"
      indexes :parent_id, type: "integer"
      indexes :parent_type, type: "keyword"
      indexes :published, type: "boolean"
      indexes :published_at, type: "date"
      indexes :site_id, type: "integer"
      indexes :spam, type: "boolean"
      indexes :tags, type: "text", analyzer: "ascii_snowball_analyzer" do
        indexes :keyword, type: "keyword"
      end
      indexes :title, type: "text", analyzer: "ascii_snowball_analyzer" do
        indexes :standard, type: "text", analyzer: "standard_analyzer"
      end
      indexes :user do
        indexes :id, type: "integer"
        indexes :login, analyzer: "ascii_snowball_analyzer"
        indexes :name, analyzer: "ascii_snowball_analyzer"
        indexes :spammer, type: "boolean"
      end
      indexes :uuid, type: "keyword"
    end
  end

  # Trips (Trip < Post) are a legacy feature and stay out of the index
  def self.prune_batch_for_index( batch )
    batch.reject {| post | post.is_a?( Trip ) }
  end

  # elastic_index! skips trips via prune_batch_for_index, but elastic_delete!
  # has no prune check
  def elastic_delete!
    return if is_a?( Trip )

    super
  end

  def self.prepare_batch_for_index( batch )
    counts = Comment.where( parent_type: "Post", parent_id: batch.map( &:id ) ).group( :parent_id ).count
    batch.each {| post | post.indexed_comments_count = counts[post.id] || 0 }
  end

  def as_indexed_json( _options = {} )
    preload_for_elastic_index
    body_text = indexed_body_text
    {
      id: id,
      uuid: uuid,
      parent_type: parent_type,
      parent_id: parent_id,
      site_id: indexed_site_id,
      user: indexed_user,
      title: title,
      body: body_text,
      body_excerpt: body_text.truncate( BODY_EXCERPT_LENGTH, separator: " " ),
      tags: tags.map {| tag | tag.name.downcase }.uniq,
      published_at: published_at,
      published: published_at.present?,
      spam: known_spam?,
      locale: locale,
      # count, not size: size marks an empty association loaded, which would
      # leave a reindexed instance stuck at 0
      comments_count: indexed_comments_count || comments.count
    }
  end

  # Plain text of the body, capped. Not memoized: callbacks reindex the same
  # instance after its body changes.
  def indexed_body_text
    fragment = Nokogiri::HTML::DocumentFragment.parse( body.to_s )
    fragment.css( "script, style" ).remove
    fragment.xpath( ".//text()" ).map( &:text ).join( " " ).squish[0, INDEXED_BODY_MAX_LENGTH]
  end

  private

  def indexed_site_id
    case parent_type
    when "Site" then parent_id
    when "User" then parent&.site_id
    end
  end

  def indexed_user
    return unless user

    {
      id: user.id,
      login: user.login,
      name: user.name,
      spammer: user.spammer? || false
    }
  end
end
