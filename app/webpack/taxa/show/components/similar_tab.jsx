import React, { PropTypes } from "react";
import { Grid, Row, Col } from "react-bootstrap";
import TaxonThumbnail from "./taxon_thumbnail";

const SimilarTab = ( { results, place, showNewTaxon } ) => {
  let content;
  if ( results && results.length > 0 ) {
    content = (
      <div className="thumbnails">
        { results.map( result =>
          <TaxonThumbnail
            taxon={result.taxon}
            key={`similar-taxon-${result.taxon.id}`}
            badgeText={result.count}
            badgeTip={I18n.t( "x_misidentifications_of_this_species", { count: result.count } )}
            height={190}
            truncate={20}
            onClick={ e => {
              if ( !showNewTaxon ) return true;
              e.preventDefault( );
              showNewTaxon( result.taxon );
              return false;
            } }
          />
        ) }
      </div>
    );
  } else if ( results ) {
    content = <p>{ I18n.t( "no_misidentifications_yet" ) }</p>;
  } else {
    content = <div className="loading status">{ I18n.t( "loading" ) }</div>;
  }
  return (
    <Grid className="SimilarTab">
      <Row>
        <Col xs={12}>
          <h2>
            {
              place ?
                <span
                  dangerouslySetInnerHTML={ { __html:
                    I18n.t(
                      "other_species_commonly_misidentified_as_this_species_in_place_html",
                      { place: place.display_name, url: `/places/${place.id}` }
                    )
                  } }
                ></span>
                :
                I18n.t( "other_species_commonly_misidentified_as_this_species" )
            }
          </h2>
          { content }
        </Col>
      </Row>
    </Grid>
  );
};

SimilarTab.propTypes = {
  results: PropTypes.array,
  place: PropTypes.object,
  showNewTaxon: PropTypes.func
};

export default SimilarTab;
