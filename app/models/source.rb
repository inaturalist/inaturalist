# frozen_string_literal: true

class Source < ApplicationRecord
  has_many :taxa
  has_many :taxon_names
  has_many :taxon_ranges
  has_many :taxon_changes
  has_many :places
  has_many :taxon_frameworks
  has_many :place_geometries
  belongs_to :user

  MAX_LENGTH = 512
  validates_presence_of :title
  validates_length_of :citation, maximum: Source::MAX_LENGTH

  attr_accessor :html

  def to_s
    "<Source #{id}: #{title}>"
  end

  def user_name
    user.try( &:login ) || "unknown"
  end

  def editable_by?( editing_user )
    return false if editing_user.blank?
    return true if editing_user.is_curator?

    editing_user.id == user_id
  end

  def self.from_eol_data_object( data_object )
    uri = EolService.uri_from_data_object
    if ( existing = Source.find_by_url( uri ) )
      return existing
    end

    Source.new(
      title => ( data_object.at( "title" ) || data_object.at( "subject" ) ).
        content.split( "#" ).last.underscore.humanize,
      citation => data_object.at( "bibliographicCitation" ).try( :content )
    )
  end
end
