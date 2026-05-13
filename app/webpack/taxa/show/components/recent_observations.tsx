import React, { useRef } from "react";
import Carousel from "../../../shared/components/carousel";
import TaxonPhoto from "../../../shared/components/taxon_photo";

interface Props {
  observations?: object[];
  showPhotoModal?: ( photo: object, taxon: object, observation: object ) => void;
  url?: string;
}

const RecentObservations = ( { observations, showPhotoModal, url }: Props ) => {
  const firstItemRef = useRef( null );

  if ( !observations ) { return <span />; }

  const items = observations.map( ( observation: any, i ) => (
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
        url={url}
      />
    </div>
  );
};

export default RecentObservations;
