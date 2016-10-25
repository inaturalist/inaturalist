import React, { PropTypes } from "react";
import { Grid, Row, Col } from "react-bootstrap";
import _ from "lodash";
import Carousel from "./carousel";
import TaxonThumbnail from "./taxon_thumbnail";

const HighlightsTab = ( { trendingTaxa, rareTaxa, trendingUrl, rareUrl } ) => {
  let trending = (
    <p className="text-muted text-center">
      <i className="fa fa-refresh fa-spin"></i>
      { I18n.t( "loading" ) }
    </p>
  );
  if ( trendingTaxa ) {
    trending = (
      <Carousel
        title={ I18n.t( "trending" ) }
        url={ trendingUrl }
        description={ I18n.t( "views.taxa.show.trending_desc" ) }
        noContent={ I18n.t( "views.taxa.show.no_trending_desc" ) }
        items={ _.chunk( trendingTaxa, 6 ).map( chunk => (
          <Row>
            {
              chunk.map( taxon => (
                <Col xs={2}>
                  <TaxonThumbnail taxon={taxon} />
                </Col>
              ) )
            }
          </Row>
        ) ) }
      />
    );
  }
  let rare = (
    <p className="text-muted text-center">
      <i className="fa fa-refresh fa-spin"></i>
      { I18n.t( "loading" ) }
    </p>
  );
  if ( rareTaxa ) {
    rare = (
      <Carousel
        title={ I18n.t( "rare" ) }
        description={ I18n.t( "views.taxa.show.rare_desc" ) }
        noContent={ I18n.t( "no_observations_yet" ) }
        items={ _.chunk( rareTaxa, 6 ).map( chunk => (
          <Row>
            {
              chunk.map( taxon => (
                <Col xs={2}>
                  <TaxonThumbnail taxon={taxon} />
                </Col>
              ) )
            }
          </Row>
        ) ) }
      />
    );
  }
  return (
    <Grid className="HighlightsTab">
      <Row>
        <Col xs={12}>
          <div className="trending">
            { trending }
          </div>
          <div className="rare">
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
