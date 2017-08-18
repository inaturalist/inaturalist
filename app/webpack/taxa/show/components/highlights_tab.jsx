import React, { PropTypes } from "react";
import { Grid, Row, Col } from "react-bootstrap";
import moment from "moment";
import _ from "lodash";
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
          taxa={ discoveries ? discoveries.map( d => d.taxon ) : null }
          captionForTaxon={ taxon => {
            const discovery = _.find( discoveries, d => d.taxon.id === taxon.id );
            if ( !discoveries ) {
              return <span></span>;
            }
            let icon;
            if ( discovery.identification.category === "leading" ) {
              icon = <i className="fa fa-bullhorn" />;
            } else if ( discovery.identification.category === "improving" ) {
              icon = <i className="fa fa-trophy" />;
            }
            return (
              <div className="discovery-caption">
                <span className={ `ident-${discovery.identification.category} pull-left` }>
                  { icon } { I18n.t( discovery.identification.category ) }
                </span> <a
                  href={ `/observations/${discovery.identification.observation.id}`}
                  className="text-muted"
                >
                  { moment( discovery.identification.created_at ).fromNow( ) }
                </a>
              </div>
            );
          } }
          description={ I18n.t( "views.taxa.show.discoveries_desc" ) }
          showNewTaxon={ showNewTaxon }
          urlForTaxon={ taxon => {
            const discovery = _.find( discoveries, d => d.taxon.id === taxon.id );
            if ( !discoveries ) {
              return null;
            }
            return `/observations/${discovery.identification.observation.id}`;
          } }
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
