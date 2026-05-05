import React, { useState, useMemo, useRef } from "react";
import _ from "lodash";
import Carousel from "./carousel";
import TaxonPhoto from "../../shared/components/taxon_photo";
// import Carousel from "../../../shared/components/carousel";

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

const calcChunkSize = () => Math.floor( window.innerWidth / TAXON_PHOTO_SIZE );

const RecentObservations = ( {
  observations, showPhotoModal, url
}: RecentObservationsProps ) => {
  if ( !observations ) { return ( <span /> ); }

  const itemRef = useRef<HTMLDivElement>(null);
  const [chunkSize, setChunkSize] = useState( calcChunkSize() );

  window.addEventListener( "resize", ( ) => {
    setChunkSize( calcChunkSize() );
  } );

  const items = useMemo( ( ) => {
    const observationChunks = _.chunk( observations, chunkSize );
    return observationChunks.map( chunk => {
      const images = chunk.map( (observation, i) => (
        <TaxonPhoto
          key={`recent-observations-obs-${observation.id}`}
          photo={observation.photos[0]}
          taxon={observation.taxon}
          observation={observation}
          showTaxonPhotoModal={( ) => showPhotoModal?.(
            observation.photos[0],
            observation.taxon,
            observation
          )}
          ref={i === 0 ? itemRef : null}
        />
      ) );
      const placeholders = Array.from( { length: chunkSize - chunk.length - 1 }, ( _el, i ) => (
        <div className="placeholder" key={`recent-observations-placeholder-${chunk[0]?.id}-${i}`} />
      ) );
      const viewAll = chunk.length < chunkSize && <a href={url} className="viewall">{ I18n.t( "view_all" ) }</a>;
      return (
        <div className="slide" key={`recent-observations-${chunk[0].id}`}>
          {images}
          {placeholders}
          {viewAll}
        </div>
      );
    } );
  }, [observations, chunkSize] );

  console.log('itemRef', itemRef);

  return (
    <div className={`RecentObservations ${observations.length < chunkSize ? "no-slides" : ""}`}>
      <Carousel
        title={I18n.t( "recent_observations_" )}
        noContent={I18n.t( "no_observations_yet" )}
        items={items}
        itemRef={itemRef}
      />
    </div>
  );
};

export default RecentObservations;
