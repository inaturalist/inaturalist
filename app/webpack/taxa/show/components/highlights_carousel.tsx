import React, { useRef } from "react";
import _ from "lodash";
import ObservationsGridItem from "../../../shared/components/observations_grid_item";
import Carousel from "../../../shared/components/carousel";
import TaxonThumbnail from "./taxon_thumbnail";

interface Taxon {
  id: number;
  [key: string]: unknown;
}

interface Observation {
  id: number;
  [key: string]: unknown;
}

interface Config {
  currentUser?: unknown;
  [key: string]: unknown;
}

interface HiglightsCarouselProps {
  title?: string;
  description?: string | React.ReactNode;
  url?: string;
  taxa?: Taxon[] | null;
  observations?: Observation[] | null;
  showNewTaxon?: ( taxon: Taxon ) => void;
  captionForTaxon?: ( taxon: Taxon ) => React.ReactNode;
  captionForObservation?: ( obs: Observation ) => React.ReactNode;
  urlForTaxon?: ( taxon: Taxon ) => string | null;
  config?: Config;
}

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
}: HiglightsCarouselProps ) => {
  const itemRef = useRef<HTMLDivElement>( null );
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

  let items: React.ReactNode[];
  if ( taxa ) {
    items = taxa.map( ( taxon, i ) => (
      <div
        key={`${keyBase}-item-${taxon.id}`}
        ref={i === 0 ? itemRef : null}
        className="carousel-item"
      >
        <TaxonThumbnail
          taxon={taxon}
          height={200}
          onClick={( e: React.MouseEvent ) => {
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
      </div>
    ) );
  } else {
    items = _.uniqBy( observations, o => o.id ).map( ( obs, i ) => (
      <div
        key={`${keyBase}-item-${obs.id}`}
        ref={i === 0 ? itemRef : null}
        className="carousel-item"
      >
        <ObservationsGridItem
          observation={obs}
          controls={captionForObservation ? captionForObservation( obs ) : null}
          user={config?.currentUser}
        />
      </div>
    ) );
  }

  console.log('items', items);

  return (
    <Carousel
      title={title}
      description={description}
      url={url}
      noContent={I18n.t( "no_observations_yet" )}
      items={items}
      itemRef={itemRef}
    />
  );
};

export default HiglightsCarousel;
