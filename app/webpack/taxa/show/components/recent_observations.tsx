import React, { useState, useMemo } from "react";
import _ from "lodash";
import Carousel from "./carousel";
import TaxonPhoto from "../../shared/components/taxon_photo";

const TAXON_PHOTO_SIZE = 120;

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

  const [chunkSize, setChunkSize] = useState( window.innerWidth / TAXON_PHOTO_SIZE );
  window.addEventListener( "resize", ( ) => {
    setChunkSize( window.innerWidth / TAXON_PHOTO_SIZE );
  } );

  const items = useMemo( ( ) => {
    const observationChunks = _.chunk( observations, chunkSize );
    const slides = observationChunks.map( chunk => (
      <div className="slide" key={`recent-observations-${chunk[0].id}`}>
        {chunk.map( observation => (
          <TaxonPhoto
            key={`recent-observations-obs-${observation.id}`}
            photo={observation.photos[0]}
            taxon={observation.taxon}
            observation={observation}
            width={TAXON_PHOTO_SIZE}
            height={TAXON_PHOTO_SIZE}
            showTaxonPhotoModal={( ) => showPhotoModal?.(
              observation.photos[0],
              observation.taxon,
              observation
            )}
          />
        ) )}
      </div>
    ) );
    if ( slides.length < chunkSize ) {
      slides.push(
        <a href={url} className="viewall">{ I18n.t( "view_all" ) }</a>
      );
    }

    return slides;
  }, [observations, chunkSize] );

  return (
    <div className={`RecentObservations ${observations.length < chunkSize ? "no-slides" : ""}`}>
      <Carousel
        title={I18n.t( "recent_observations_" )}
        noContent={I18n.t( "no_observations_yet" )}
        items={items}
      />
    </div>
  );
};

export default RecentObservations;
