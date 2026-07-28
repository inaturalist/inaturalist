import React from "react";
import Carousel from "../../../shared/components/carousel";
import TaxonPhoto from "../../../shared/components/taxon_photo";
import type { Photo, Taxon, Observation } from "../../../shared/types";
import taxaShowResponsive from "../responsive";
import RecentObservationsLegacy from "./recent_observations_legacy";

interface RecentObservation extends Observation {
  photos: Photo[];
  taxon: Taxon;
}

interface Props {
  observations?: RecentObservation[];
  showPhotoModal?: ( photo: Photo, taxon: Taxon, observation: Observation ) => void;
  url?: string;
}

const RecentObservationsResponsive = ( { observations, showPhotoModal, url }: Props ) => {
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
        className="recent-observations-carousel"
        titleClassName="recent-observations-title"
        linkClassName="recent-observations-link"
      />
    </div>
  );
};

// Renders the pre-WEB-984 layout unless the user is testing responsiveness.
// The legacy module is untyped JS, so its props are asserted to match.
type GateProps = React.ComponentProps<typeof RecentObservationsResponsive>;
const LegacyFallback = RecentObservationsLegacy as unknown as React.ComponentType<GateProps>;

/* eslint-disable react/jsx-props-no-spreading */
const RecentObservations = ( props: GateProps ) => (
  taxaShowResponsive( )
    ? <RecentObservationsResponsive {...props} />
    : <LegacyFallback {...props} />
);
/* eslint-enable react/jsx-props-no-spreading */

export default RecentObservations;
