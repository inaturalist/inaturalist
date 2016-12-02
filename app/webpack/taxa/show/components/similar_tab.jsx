import React, { PropTypes } from "react";
import { Grid, Row, Col } from "react-bootstrap";
import TaxonThumbnail from "./taxon_thumbnail";

const SimilarTab = ( { taxa } ) => {
  let content;
  if ( taxa && taxa.length > 0 ) {
    content = (
      <div className="thumbnails">
        { taxa.map( similarTaxon =>
          <TaxonThumbnail taxon={similarTaxon} key={`similar-taxon-${similarTaxon.id}`} />
        ) }
      </div>
    );
  } else if ( taxa ) {
    content = <p>{ I18n.t( "no_misidentifications_yet" ) }</p>;
  } else {
    content = <div className="loading status">{ I18n.t( "loading" ) }</div>;
  }
  return (
    <Grid className="SimilarTab">
      <Row>
        <Col xs={12}>
          <h2>
            { I18n.t( "other_taxa_commonly_misidentified_as_this_species" ) }
          </h2>
          { content }
        </Col>
      </Row>
    </Grid>
  );
};

SimilarTab.propTypes = {
  taxa: PropTypes.array
};

export default SimilarTab;
