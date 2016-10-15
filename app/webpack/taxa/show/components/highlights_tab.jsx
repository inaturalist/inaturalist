import React, { PropTypes } from "react";
import { Grid, Row, Col } from "react-bootstrap";
import CoverImage from "./cover_image";
import { urlForTaxon } from "../util";

const HighlightsTab = ( { trendingTaxa, rareTaxa } ) => (
  <Grid className="HighlightsTab">
    <Row>
      <Col xs={12}>
        <div className="trending">
          <h2>Trending</h2>
          { trendingTaxa.map( taxon => (
            <a
              key={`rare-taxon-${taxon.id}`}
              href={urlForTaxon( taxon )}
              title={taxon.preferred_common_name || taxon.name}
            >
              <CoverImage
                src={taxon.defaultPhoto.photoUrl( "medium" )}
                low={taxon.defaultPhoto.photoUrl( "square" )}
                height={100}
              />
            </a>
          ) ) }
        </div>
        <div className="rare">
          <h2>Rare</h2>
          { rareTaxa.map( taxon => {
            const img = taxon.defaultPhoto ? (
              <CoverImage
                src={taxon.defaultPhoto.photoUrl( "medium" )}
                low={taxon.defaultPhoto.photoUrl( "square" )}
                height={100}
              />
            ) : (
              <i
                className={
                  `icon-iconic-${taxon.iconic_taxon_name ? taxon.iconic_taxon_name.toLowerCase( ) : "unknown"}`
                }
              ></i>
            );
            return (
              <a
                key={`rare-taxon-${taxon.id}`}
                href={urlForTaxon( taxon )}
                title={taxon.preferred_common_name || taxon.name}
              >
                { img }
              </a>
            );
          } ) }
        </div>
      </Col>
    </Row>
  </Grid>
);

HighlightsTab.propTypes = {
  trendingTaxa: PropTypes.array,
  rareTaxa: PropTypes.array
};

HighlightsTab.defaultProps = {
  trendingTaxa: [],
  rareTaxa: []
};

export default HighlightsTab;
