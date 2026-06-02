import React from "react";
import _ from "lodash";
import ObservationsGridItem from "../../../shared/components/observations_grid_item";
import Carousel from "../../../shared/components/carousel";
import TaxonThumbnail from "../../../shared/components/taxon_thumbnail";
import type { Taxon, Observation, Config } from "../../../shared/types";

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
  config?: Config;
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
    items = taxa.map( taxon => (
      <TaxonThumbnail
        key={`highlights-taxon-${taxon.id}`}
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
    items = _.uniqBy( observations, o => o.id ).map( obs => (
      <div
        key={`highlights-obs-${obs.id}`}
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
    />
  );
};

export default HighlightsCarousel;
