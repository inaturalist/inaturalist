import React, { useState, useMemo, useRef } from "react";
import _ from "lodash";
import TaxonPhoto from "../../shared/components/taxon_photo";
import Carousel from "../../../shared/components/carousel";

interface ObsPhoto {
  id: number;
  [key: string]: unknown;
}

interface ObsTaxon {
  id: number;
  [key: string]: unknown;
}

interface Observation {
  id: number;
  photos: ObsPhoto[];
  taxon: ObsTaxon;
}

interface RecentObservationsProps {
  observations?: Observation[];
  showPhotoModal?: ( photo: ObsPhoto, taxon: ObsTaxon, observation: Observation ) => void;
  url?: string;
}

const RecentObservations = ( {
  observations, showPhotoModal, url
}: RecentObservationsProps ) => {
  if ( !observations ) { return ( <span /> ); }

  const itemRef = useRef<HTMLDivElement>( null );

  const items = useMemo( () => {
    const images = observations.map( ( observation, idx ) => (
      <TaxonPhoto
        key={`recent-observations-obs-${observation.id}`}
        photo={observation.photos[0]}
        size="medium"
        taxon={observation.taxon}
        observation={observation}
        showTaxonPhotoModal={( ) => showPhotoModal?.(
          observation.photos[0],
          observation.taxon,
          observation
        )}
        ref={idx === 0 ? itemRef : null}
      />
    ) );
    return images;
  }, [observations] );

  return (
    <div className="RecentObservations">
      <Carousel
        title={I18n.t( "recent_observations_" )}
        noContent={I18n.t( "no_observations_yet" )}
        items={items}
        finalItem={( <a key="viewall" href={url} className="viewall carousel-item">{ I18n.t( "view_all" ) }</a> )}
        itemRef={itemRef}
      />
    </div>
  );
};

export default RecentObservations;
