import React, { PropTypes } from "react";
import _ from "lodash";
import { Row, Col } from "react-bootstrap";
import ObservationsGridItem from "../../../shared/components/observations_grid_item";
import Carousel from "./carousel";
import TaxonThumbnail from "./taxon_thumbnail";

const HiglightsCarousel = ( {
  title,
  description,
  url,
  taxa,
  observations,
  showNewTaxon,
  captionForTaxon,
  captionForObservation,
  urlForTaxon
} ) => {
  const photosPerSlide = 4;
  const columnWidth = 3;
  const thumbnailHeight = 200;
  const thumbnailTruncation = 27;
  const keyBase = _.snakeCase( title );
  if ( !taxa && !observations ) {
    return (
      <div>
        <h2>{ title }</h2>
        <p className="text-muted text-center">
          <i className="fa fa-refresh fa-spin"></i> { I18n.t( "loading" ) }
        </p>
      </div>
    );
  }
  let items;
  if ( taxa ) {
    const chunkedTaxa = _.chunk( taxa, photosPerSlide );
    if (
      chunkedTaxa &&
      chunkedTaxa[chunkedTaxa.length - 1] &&
      chunkedTaxa[chunkedTaxa.length - 1].length === photosPerSlide
    ) {
      chunkedTaxa[chunkedTaxa.length - 1].pop( );
    }
    items = (
      _.map( chunkedTaxa, ( chunk, i ) => (
        <Row key={`${keyBase}-${i}`}>
          {
            chunk.map( taxon => (
              <Col xs={ columnWidth } key={ `${keyBase}-item-${taxon.id}` }>
                <TaxonThumbnail
                  taxon={ taxon }
                  height={ thumbnailHeight }
                  truncate={ thumbnailTruncation }
                  onClick={ e => {
                    if ( !showNewTaxon ) return true;
                    if ( e.metaKey || e.ctrlKey ) return true;
                    e.preventDefault( );
                    showNewTaxon( taxon );
                    return false;
                  } }
                  captionForTaxon={ captionForTaxon }
                  urlForTaxon={ urlForTaxon }
                />
              </Col>
            ) )
          }
        </Row>
      ) )
    );
  } else {
    items = (
      _.map( _.chunk( _.uniqBy( observations, o => o.id ), photosPerSlide ), ( chunk, i ) => (
        <Row key={`${keyBase}-${i}`}>
          {
            chunk.map( obs => (
              <Col xs={columnWidth} key={`${keyBase}-item-${obs.id}`}>
                <ObservationsGridItem
                  observation={ obs }
                  controls={ captionForObservation ? captionForObservation( obs ) : null }
                />
              </Col>
            ) )
          }
        </Row>
      ) )
    );
  }
  return (
    <Carousel
      title={ title }
      description={ description }
      url={ url }
      noContent={ I18n.t( "no_observations_yet" ) }
      items={ items }
    />
  );
};

HiglightsCarousel.propTypes = {
  title: PropTypes.string,
  description: PropTypes.oneOfType( [PropTypes.string, PropTypes.element] ),
  url: PropTypes.string,
  taxa: PropTypes.array,
  observations: PropTypes.array,
  showNewTaxon: PropTypes.func,
  captionForObservation: PropTypes.func,
  captionForTaxon: PropTypes.func,
  urlForTaxon: PropTypes.func
};

export default HiglightsCarousel;
