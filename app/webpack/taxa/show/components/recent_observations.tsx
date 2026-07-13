import React from "react";
import Carousel from "../../../shared/components/carousel";
import TaxonPhoto from "../../../shared/components/taxon_photo";
import type { Photo, Taxon, Observation } from "../../../shared/types";

interface RecentObservation extends Observation {
  photos: Photo[];
  taxon: Taxon;
}

interface Props {
  observations?: RecentObservation[];
  showPhotoModal?: ( photo: Photo, taxon: Taxon, observation: Observation ) => void;
  url?: string;
}

const RecentObservations = ( { observations, showPhotoModal, url }: Props ) => {
  if ( !observations ) return null;

  const items = observations
    .filter( observation => observation.photos?.[0] )
    .map( observation => {
      const photo = observation.photos[0];
      return (
        <TaxonPhoto
          key={`recent-observations-obs-${observation.id}`}
          photo={photo}
          taxon={observation.taxon}
          observation={observation}
          square
          showTaxonPhotoModal={( ) => showPhotoModal?.( photo, observation.taxon, observation )}
        />
      );
    } );

  return (
    <div className="RecentObservations">
      <Carousel
        title={I18n.t( "recent_observations_" )}
        noContent={I18n.t( "no_observations_yet" )}
        items={items}
        url={url}
      />
    </div>
  );
};

export default RecentObservations;
