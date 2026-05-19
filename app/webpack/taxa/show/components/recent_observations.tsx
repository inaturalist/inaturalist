import React, { useRef } from "react";
import Carousel from "../../../shared/components/carousel";
import TaxonPhoto, { Photo, Taxon, Observation } from "../../../shared/components/taxon_photo";

interface RecentObservation extends Observation {
  photos: Photo[];
  taxon: Taxon;
}

interface Props {
  observations?: RecentObservation[];
  showPhotoModal?: ( photo: Photo, taxon: Taxon, observation: Observation ) => void;
}

const RecentObservations = ( { observations, showPhotoModal }: Props ) => {
  const firstItemRef = useRef<HTMLDivElement>( null );

  if ( !observations ) { return <span />; }

  const items = observations.map( ( observation, i ) => (
    <TaxonPhoto
      key={`recent-observations-obs-${observation.id}`}
      ref={i === 0 ? firstItemRef : null}
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

  return (
    <div className="RecentObservations">
      <Carousel
        title={I18n.t( "recent_observations_" )}
        noContent={I18n.t( "no_observations_yet" )}
        items={items}
        itemRef={firstItemRef}
      />
    </div>
  );
};

export default RecentObservations;
