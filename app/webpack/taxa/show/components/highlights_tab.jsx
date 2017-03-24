import React, { PropTypes } from "react";
import { Grid, Row, Col } from "react-bootstrap";
import _ from "lodash";
import Carousel from "./carousel";
import TaxonThumbnail from "./taxon_thumbnail";

const HighlightsTab = ( {
  trendingTaxa,
  rareTaxa,
  trendingUrl,
  placeName,
  placeUrl,
  showNewTaxon
} ) => {
  let trending = (
    <h2 className="text-muted text-center">
      <i className="fa fa-refresh fa-spin"></i>
    </h2>
  );
  const photosPerSlide = 4;
  const columnWidth = 3;
  const thumbnailHeight = 200;
  const thumbnailTruncation = 50;
  if ( trendingTaxa ) {
    const trendingChunks = _.chunk( trendingTaxa, photosPerSlide );
    if (
      trendingChunks &&
      trendingChunks[trendingChunks.length - 1] &&
      trendingChunks[trendingChunks.length - 1].length === photosPerSlide
    ) {
      trendingChunks[trendingChunks.length - 1].pop( );
    }
    trending = (
      <Carousel
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
        noContent={ I18n.t( "views.taxa.show.no_trending_desc" ) }
        items={ _.map( trendingChunks, ( chunk, i ) => (
          <Row key={`trending-${i}`} className={`trending-${i}`}>
            {
              chunk.map( taxon => (
                <Col xs={columnWidth} key={`trending-taxon-${taxon.id}`}>
                  <TaxonThumbnail
                    taxon={taxon}
                    height={thumbnailHeight}
                    truncate={thumbnailTruncation}
                    onClick={ e => {
                      if ( !showNewTaxon ) return true;
                      if ( e.metaKey || e.ctrlKey ) return true;
                      e.preventDefault( );
                      showNewTaxon( taxon );
                      return false;
                    } }
                  />
                </Col>
              ) )
            }
            { i === trendingChunks.length - 1 ?
              <Col xs={columnWidth}>
                <a href={trendingUrl} className="viewall">
                  { I18n.t( "view_all" ) } <i className="fa fa-arrow-circle-right"></i>
                </a>
              </Col>
              :
              null
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
        noContent={ I18n.t( "no_observations_yet" ) }
        items={ _.map( _.chunk( rareTaxa, photosPerSlide ), ( chunk, i ) => (
          <Row key={`rare-${i}`}>
            {
              chunk.map( taxon => (
                <Col xs={columnWidth} key={`rare-taxon-${taxon.id}`}>
                  <TaxonThumbnail
                    taxon={taxon}
                    height={thumbnailHeight}
                    truncate={thumbnailTruncation}
                    onClick={ e => {
                      if ( !showNewTaxon ) return true;
                      if ( e.metaKey || e.ctrlKey ) return true;
                      e.preventDefault( );
                      showNewTaxon( taxon );
                      return false;
                    } }
                  />
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
  placeName: PropTypes.string,
  placeUrl: PropTypes.string,
  trendingTaxa: PropTypes.array,
  rareTaxa: PropTypes.array,
  trendingUrl: PropTypes.string,
  showNewTaxon: PropTypes.func
};

export default HighlightsTab;
