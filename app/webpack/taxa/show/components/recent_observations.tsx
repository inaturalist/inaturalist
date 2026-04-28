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

const calcChunkSize = () => Math.floor( window.innerWidth / TAXON_PHOTO_SIZE );

const RecentObservations = ( {
  observations, showPhotoModal, url
}: RecentObservationsProps ) => {
  if ( !observations ) { return ( <span /> ); }

  const [chunkSize, setChunkSize] = useState( calcChunkSize() );
  window.addEventListener( "resize", ( ) => {
    setChunkSize( calcChunkSize() );
  } );

  const items = useMemo( ( ) => {
    const observationChunks = _.chunk( observations, chunkSize );
    return observationChunks.map( ( chunk, index ) => {
      const images = chunk.map( observation => (
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
        />
      ) );
      const placeholders = Array.from( { length: chunkSize - chunk.length - 1 }, ( _, i ) => (
        <div className="placeholder" key={`recent-observations-placeholder-${index}-${i}`} />
      ) );
      const viewAll = chunk.length < chunkSize && <a href={url} className="viewall">{ I18n.t( "view_all" ) }</a>;
      return (
        <div className="slide" key={`recent-observations-${chunk[0].id}`}>
          {[images, placeholders, viewAll]}
        </div>
      );
    } );
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
