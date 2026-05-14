import React, { useRef } from "react";
import PropTypes from "prop-types";
import _ from "lodash";
import ObservationsGridItem from "../../../shared/components/observations_grid_item";
import Carousel from "../../../shared/components/carousel";
import TaxonThumbnail from "../../../shared/components/taxon_thumbnail";

const ITEM_WIDTH = 200;

const HiglightsCarousel = ( {
  title,
  description,
  url,
  taxa,
  observations,
  showNewTaxon,
  captionForTaxon,
  captionForObservation,
  urlForTaxon,
  config
} ) => {
  const firstItemRef = useRef( null );

  if ( !taxa && !observations ) {
    return (
      <div>
        <h2>{ title }</h2>
        <p className="text-muted text-center">
          <i className="fa fa-refresh fa-spin" />
          { I18n.t( "loading" ) }
        </p>
      </div>
    );
  }

  let items;
  if ( taxa ) {
    items = taxa.map( ( taxon, i ) => (
      <TaxonThumbnail
        key={`highlights-taxon-${taxon.id}`}
        ref={i === 0 ? firstItemRef : null}
        taxon={taxon}
        style={{ "--taxon-thumbnail-width": `${ITEM_WIDTH}px` }}
        onClick={e => {
          if ( !showNewTaxon ) return true;
          if ( e.metaKey || e.ctrlKey ) return true;
          e.preventDefault( );
          showNewTaxon( taxon );
          return false;
        }}
        captionForTaxon={captionForTaxon}
        urlForTaxon={urlForTaxon}
        config={config}
      />
    ) );
  } else {
    items = _.uniqBy( observations, o => o.id ).map( ( obs, i ) => (
      <div
        key={`highlights-obs-${obs.id}`}
        ref={i === 0 ? firstItemRef : null}
        style={{ width: ITEM_WIDTH }}
      >
        <ObservationsGridItem
          observation={obs}
          controls={captionForObservation ? captionForObservation( obs ) : null}
          user={config.currentUser}
        />
      </div>
    ) );
  }

  return (
    <Carousel
      title={title}
      description={description}
      url={url}
      noContent={I18n.t( "no_observations_yet" )}
      items={items}
      itemRef={firstItemRef}
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
  urlForTaxon: PropTypes.func,
  config: PropTypes.object
};

export default HiglightsCarousel;
