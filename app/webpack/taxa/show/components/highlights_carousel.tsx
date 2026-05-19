import React, { useRef } from "react";
import _ from "lodash";
import ObservationsGridItem from "../../../shared/components/observations_grid_item";
import Carousel from "../../../shared/components/carousel";
import TaxonThumbnail, { Taxon } from "../../../shared/components/taxon_thumbnail";

interface Observation {
  id: number;
  [key: string]: unknown;
}

interface Props {
  title?: string;
  description?: string | React.ReactNode;
  url?: string;
  taxa?: Taxon[];
  observations?: Observation[];
  showNewTaxon?: ( taxon: Taxon ) => void;
  captionForObservation?: ( obs: Observation ) => React.ReactNode;
  captionForTaxon?: ( taxon: Taxon ) => React.ReactNode;
  urlForTaxon?: ( taxon: Taxon ) => string | undefined;
  config?: { currentUser?: unknown; [key: string]: unknown };
}

const HighlightsCarousel = ( {
  title,
  description,
  url,
  taxa,
  observations,
  showNewTaxon,
  captionForTaxon,
  captionForObservation,
  urlForTaxon,
  config = {}
}: Props ) => {
  const firstItemRef = useRef<HTMLDivElement>( null );

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

  let items: React.ReactElement[];
  if ( taxa ) {
    items = taxa.map( ( taxon, i ) => (
      <TaxonThumbnail
        key={`highlights-taxon-${taxon.id}`}
        ref={i === 0 ? firstItemRef : null}
        taxon={taxon}
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
      >
        <ObservationsGridItem
          observation={obs as any}
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

export default HighlightsCarousel;
