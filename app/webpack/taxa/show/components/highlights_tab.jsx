import React from "react";
import PropTypes from "prop-types";
import { Grid, Row, Col } from "react-bootstrap";
import LazyLoad from "react-lazy-load";
import moment from "moment";
import _ from "lodash";
import HighlightsCarousel from "./highlights_carousel";

const HighlightsTab = ( {
  trendingTaxa,
  wantedTaxa,
  discoveries,
  trendingUrl,
  placeName,
  placeUrl,
  showNewTaxon,
  wantedShown,
  discoveriesShown,
  config,
  fetchRecent,
  fetchWanted
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
          showNewTaxon={ showNewTaxon }
          config={ config }
        />
        { discoveriesShown ? (
          <LazyLoad
            debounce={false}
            height={391}
            offset={100}
            onContentVisible={fetchRecent}
          >
            <HighlightsCarousel
              title={ I18n.t( "discoveries" ) }
              taxa={ discoveries ? discoveries.map( d => d.taxon ) : null }
              showNewTaxon={ showNewTaxon }
              captionForTaxon={ taxon => {
                const discovery = _.find( discoveries, d => d.taxon.id === taxon.id );
                if ( !discoveries ) {
                  return <span></span>;
                }
                // let icon;
                // if ( discovery.identification.category === "leading" ) {
                //   icon = <i className="fa fa-bullhorn" />;
                // } else if ( discovery.identification.category === "improving" ) {
                //   icon = <i className="fa fa-trophy" />;
                // }
                return (
                  <div className="discovery-caption">
                    { /*
                      <span className={ `ident-${discovery.identification.category} pull-left` }>
                        { icon } { I18n.t( discovery.identification.category ) }
                      </span>
                    */ }
                    <a
                      href={ `/observations/${discovery.identification.observation.id}`}
                      className="text-muted"
                    >
                      { moment( discovery.identification.created_at ).fromNow( ) }
                    </a>
                  </div>
                );
              } }
              description={ I18n.t( "views.taxa.show.discoveries_desc" ) }
              urlForTaxon={ taxon => {
                const discovery = _.find( discoveries, d => d.taxon.id === taxon.id );
                if ( !discoveries ) {
                  return null;
                }
                return `/observations/${discovery.identification.observation.id}`;
              } }
              config={ config }
            />
          </LazyLoad>
        ) : null }
        { wantedShown ? (
          <LazyLoad
            debounce={false}
            height={371}
            offset={100}
            onContentVisible={fetchWanted}
          >
            <div className={!wantedTaxa || wantedTaxa.length === 0 ? "hidden" : ""}>
              <HighlightsCarousel
                title={ I18n.t( "wanted" ) }
                description={ I18n.t( "views.taxa.show.wanted_desc" ) }
                taxa={ wantedTaxa ? wantedTaxa.slice( 0, 20 ) : null }
                showNewTaxon={ showNewTaxon }
                config={ config }
              />
            </div>
          </LazyLoad>
        ) : null }
      </Col>
    </Row>
  </Grid>
);

HighlightsTab.propTypes = {
  placeName: PropTypes.string,
  placeUrl: PropTypes.string,
  trendingTaxa: PropTypes.array,
  wantedTaxa: PropTypes.array,
  discoveries: PropTypes.array,
  trendingUrl: PropTypes.string,
  showNewTaxon: PropTypes.func,
  discoveriesShown: PropTypes.bool,
  wantedShown: PropTypes.bool,
  config: PropTypes.object,
  fetchRecent: PropTypes.func,
  fetchWanted: PropTypes.func
};

export default HighlightsTab;
