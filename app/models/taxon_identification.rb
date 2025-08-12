# frozen_string_literal: true

class TaxonIdentification < Identification
  acts_as_elastic_model

  self.inheritance_column = nil

  def as_indexed_json( _options = {} )
    return nil if body.blank? || !current?
    {
      id: id,
      uuid: uuid,
      created_at: created_at,
      observation: {
        id: observation.id,
        annotations: observation.annotations.reject( &:term_taxon_mismatch? ).map( &:as_indexed_json ),
        taxon: {
          id: observation.taxon.id,
          ancestor_ids: ( (
            observation.taxon.ancestry ?
              observation.taxon.ancestry.split( "/" ).map( &:to_i ) :
              []
          ) << observation.taxon.id )
        },
        user: {
          id: observation.user_id
        }
      },
      user: {
        id: user_id
      },
      taxon: {
        id: taxon.id,
        ancestor_ids: ( ( taxon.ancestry ? taxon.ancestry.split( "/" ).map( &:to_i ) : [] ) << id )
      },
      body: body,
      body_word_length: body.blank? ? 0 : body.split( /\s+/ ).length,
      body_character_length: body.blank? ? 0 : body.length,
      votes: votes_for.map( &:as_indexed_json ),
      cached_votes_total: votes_for.select{|v| v.vote_scope.blank?}.size,
    }
  end
end
