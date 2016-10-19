import React, { PropTypes } from "react";
import { Grid, Row, Col } from "react-bootstrap";
import CoverImage from "./cover_image";
import { urlForTaxon } from "../util";

const HighlightsTab = ( { trendingTaxa, rareTaxa, trendingUrl, rareUrl } ) => {
  let trending = (
    <p className="text-muted text-center">
      <i className="fa fa-refresh fa-spin"></i>
      { I18n.t( "loading" ) }
    </p>
  );
  if ( trendingTaxa && trendingTaxa.length > 0 ) {
    trending = trendingTaxa.map( taxon => (
      <a
        key={`rare-taxon-${taxon.id}`}
        href={urlForTaxon( taxon )}
        title={taxon.preferred_common_name || taxon.name}
        className="taxon-link"
      >
        <CoverImage
          src={taxon.defaultPhoto.photoUrl( "medium" )}
          low={taxon.defaultPhoto.photoUrl( "square" )}
          height={100}
        />
      </a>
    ) );
  } else if ( trendingTaxa.length === 0 ) {
    trending = (
      <p className="text-muted text-center">
        Nothing below this taxon observed in the last month.
      </p>
    );
  }
  let rare = (
    <p className="text-muted text-center">
      <i className="fa fa-refresh fa-spin"></i>
      { I18n.t( "loading" ) }
    </p>
  );
  if ( rareTaxa && rareTaxa.length > 0 ) {
    rare = rareTaxa.map( taxon => {
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
          className="taxon-link"
        >
          { img }
        </a>
      );
    } );
  } else if ( rareTaxa.length === 0 ) {
    rare = (
      <p className="text-muted text-center">
        { I18n.t( "no_observations_yet" ) }
      </p>
    );
  }
  return (
    <Grid className="HighlightsTab">
      <Row>
        <Col xs={12}>
          <div className="trending">
            <h2>
              { I18n.t( "trending" ) }
              <a href={trendingUrl} className="readmore">
                { I18n.t( "view_all" ) }
              </a>
            </h2>
            <p>
              { I18n.t( "views.taxa.show.trending_desc" ) }
            </p>
            { trending }
          </div>
          <div className="rare">
            <h2>
              { I18n.t( "rare" ) }
            </h2>
            <p>
              { I18n.t( "views.taxa.show.rare_desc" ) }
            </p>
            { rare }
          </div>
        </Col>
      </Row>
    </Grid>
  );
};

HighlightsTab.propTypes = {
  trendingTaxa: PropTypes.array,
  rareTaxa: PropTypes.array,
  trendingUrl: PropTypes.string,
  rareUrl: PropTypes.string
};

export default HighlightsTab;
