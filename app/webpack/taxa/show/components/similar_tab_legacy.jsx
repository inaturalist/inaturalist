import React from "react";
import PropTypes from "prop-types";
import { Grid, Row, Col } from "react-bootstrap";
import _ from "lodash";
import TaxonThumbnail from "./taxon_thumbnail";

const SimilarTab = ( {
  results,
  place,
  showNewTaxon,
  config,
  taxon
} ) => {
  let content;
  const rank = I18n.t( `ranks.${taxon.rank}`, { defaultValue: taxon.rank } ).toLowerCase( );
  if ( results && results.length > 0 ) {
    content = (
      <div className="thumbnails">
        { results.map( result => {
          let tip = I18n.t( "x_misidentifications_of_this_species", { count: result.count } );
          if ( taxon.rank === "genus" ) {
            tip = I18n.t( "x_misidentifications_of_species_in_this_genus", {
              count: result.count
            } );
          } else if ( taxon.rank_level > 10 ) {
            tip = I18n.t( "x_misidentifications_of_species_in_this_rank", {
              count: result.count,
              gender: _.snakeCase( result.taxon.rank ),
              rank: I18n.t( `ranks.${_.snakeCase( result.taxon.rank )}`, { defaultValue: result.taxon.rank } ).toLowerCase( )
            } );
          }
          return (
            <TaxonThumbnail
              taxon={result.taxon}
              key={`similar-taxon-${result.taxon.id}`}
              badgeText={(
                <a href={`/observations?ident_taxon_id_exclusive=${result.taxon.id},${taxon.id}&place_id=${place ? place.id : "any"}&verifiable=any`}>
                  { result.count }
                </a>
              )}
              badgeTip={tip}
              height={190}
              onClick={e => {
                if ( !showNewTaxon ) return true;
                if ( e.metaKey || e.ctrlKey ) return true;
                e.preventDefault( );
                showNewTaxon( result.taxon );
                return false;
              }}
              config={config}
            />
          );
        } ) }
      </div>
    );
  } else if ( results ) {
    content = <p>{ I18n.t( "no_misidentifications_yet" ) }</p>;
  } else {
    content = <div className="loading status">{ I18n.t( "loading" ) }</div>;
  }
  let title = I18n.t( "other_species_commonly_misidentified_as_this_species" );
  if ( taxon.rank_level > 10 ) {
    const snakeCaseRank = _.snakeCase( taxon.rank );
    if ( place ) {
      const misidentifiedOpts = {
        place: place.display_name,
        url: `/places/${place.id}`,
        gender: _.snakeCase( taxon.rank )
      };
      const misidentifiedHeader = I18n.t(
        `other_taxa_commonly_misidentified_as_this_${snakeCaseRank}_in_place_html`,
        Object.assign( {}, misidentifiedOpts, {
          default: I18n.t(
            "other_taxa_commonly_misidentified_as_this_rank_in_place_html",
            Object.assign( {}, misidentifiedOpts, { gender: snakeCaseRank } )
          )
        } )
      );
      title = (
        <span
          dangerouslySetInnerHTML={{ __html: misidentifiedHeader }}
        />
      );
    } else {
      title = I18n.t( `other_taxa_commonly_misidentified_as_this_${snakeCaseRank}`, {
        default: I18n.t( "other_taxa_commonly_misidentified_as_this_rank", {
          rank,
          gender: snakeCaseRank
        } )
      } );
    }
  } else if ( place ) {
    title = (
      <span
        dangerouslySetInnerHTML={{
          __html: I18n.t(
            "other_species_commonly_misidentified_as_this_species_in_place_html",
            { place: place.display_name, url: `/places/${place.id}` }
          )
        }}
      />
    );
  }
  return (
    <Grid className="SimilarTab">
      <Row>
        <Col xs={12}>
          <h2>{ title }</h2>
          { content }
        </Col>
      </Row>
    </Grid>
  );
};

SimilarTab.propTypes = {
  results: PropTypes.array,
  place: PropTypes.object,
  showNewTaxon: PropTypes.func,
  config: PropTypes.object,
  taxon: PropTypes.object
};

export default SimilarTab;
