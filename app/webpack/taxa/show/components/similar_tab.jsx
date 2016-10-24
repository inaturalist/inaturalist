import React, { PropTypes } from "react";
import { Grid, Row, Col } from "react-bootstrap";
import CoverImage from "./cover_image";
import SplitTaxon from "../../../shared/components/split_taxon";
import { urlForTaxon } from "../util";

const SimilarTab = ( { taxon, taxa } ) => {
  let content;
  if ( taxa && taxa.length > 0 ) {
    content = taxa.map( similarTaxon => {
      const img = similarTaxon.defaultPhoto ? (
        <CoverImage
          src={similarTaxon.defaultPhoto.photoUrl( "medium" )}
          low={similarTaxon.defaultPhoto.photoUrl( "square" )}
          height={130}
          className="photo"
        />
      ) : (
        <div className="photo">
          <i
            className={
              `icon-iconic-${similarTaxon.iconic_taxon_name ? similarTaxon.iconic_taxon_name.toLowerCase( ) : "unknown"}`
            }
          ></i>
        </div>
      );
      return (
        <div key={`similar-taxon-${similarTaxon.id}`} className="thumbnail">
          <a href={urlForTaxon( similarTaxon )}>{ img }</a>
          <div className="caption">
            <SplitTaxon taxon={similarTaxon} url={urlForTaxon( similarTaxon )} noParens />
          </div>
        </div>
      );
    } );
  } else if ( taxa ) {
    content = <p>No misidentifications yet</p>;
  } else {
    content = <div className="loading status">{ I18n.t( "loading" ) }</div>;
  }
  return (
    <Grid className="SimilarTab">
      <Row>
        <Col xs={12}>
          <h2>
            Other taxa commonly misidentified as this species:
          </h2>
          <div className="thumbnails">
            { content }
          </div>
        </Col>
      </Row>
    </Grid>
  );
};

SimilarTab.propTypes = {
  taxon: PropTypes.object,
  taxa: PropTypes.array
};

export default SimilarTab;
