import React, { PropTypes } from "react";
import { Grid, Row, Col } from "react-bootstrap";
import HighlightsCarousel from "./highlights_carousel";

const HighlightsTab = ( {
  trendingTaxa,
  rareTaxa,
  discoveries,
  trendingUrl,
  placeName,
  placeUrl,
  showNewTaxon
} ) => (
  <Grid className="HighlightsTab">
    <Row>
      <Col xs={12}>
        <HighlightsCarousel
          title={ I18n.t( "trending" ) }
          url={ trendingUrl }
          description={
            placeName ?
              <span
                dangerouslySetInnerHTML={{ __html: I18n.t(
                  "views.taxa.show.trending_in_place_desc_html",
                  { place: placeName, url: placeUrl }
                ) }}
              ></span>
              :
              I18n.t( "views.taxa.show.trending_desc" )
          }
          taxa={ trendingTaxa }
        />
        { rareTaxa && rareTaxa.length > 0 ? (
          <HighlightsCarousel
            title={ I18n.t( "rare" ) }
            description={
              placeName ?
                <span
                  dangerouslySetInnerHTML={{ __html: I18n.t(
                    "views.taxa.show.rare_in_place_desc_html",
                    { place: placeName, url: placeUrl }
                  ) }}
                ></span>
                :
                I18n.t( "views.taxa.show.rare_desc" )
            }
            taxa={ rareTaxa }
          />
        ) : null }
        <HighlightsCarousel
          title={ I18n.t( "discoveries" ) }
          observations={ discoveries ? discoveries.map( d => d.identification.observation ) : null }
          description={ I18n.t( "views.taxa.show.discoveries_desc" ) }
          showNewTaxon={ showNewTaxon }
        />
      </Col>
    </Row>
  </Grid>
);

HighlightsTab.propTypes = {
  placeName: PropTypes.string,
  placeUrl: PropTypes.string,
  trendingTaxa: PropTypes.array,
  rareTaxa: PropTypes.array,
  discoveries: PropTypes.array,
  trendingUrl: PropTypes.string,
  showNewTaxon: PropTypes.func
};

export default HighlightsTab;
