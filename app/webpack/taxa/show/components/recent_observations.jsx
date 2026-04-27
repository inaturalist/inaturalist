import React, { useState, useMemo } from "react";
import PropTypes from "prop-types";
import _ from "lodash";
import Carousel from "./carousel";
import TaxonPhoto from "../../shared/components/taxon_photo";

const TAXON_PHOTO_SIZE = 120;

const RecentObservations = ( { observations, showPhotoModal, url } ) => {
  if ( !observations ) { return ( <span /> ); }

  const [chunkSize, setChunkSize] = useState( window.innerWidth / TAXON_PHOTO_SIZE );
  window.addEventListener( "resize", () => {
    setChunkSize( window.innerWidth / TAXON_PHOTO_SIZE );
  } );

  const items = useMemo( () => {
    const observationChunks = _.chunk( observations, chunkSize );
    const items = observationChunks.map( ( chunk, i ) => (
      <div className="slide" key={`recent-observations-${i}`}>
        {chunk.map( observation => (
          <TaxonPhoto
            key={`recent-observations-obs-${observation.id}`}
            photo={observation.photos[0]}
            taxon={observation.taxon}
            observation={observation}
            width={TAXON_PHOTO_SIZE}
            height={TAXON_PHOTO_SIZE}
            showTaxonPhotoModal={( ) => showPhotoModal(
              observation.photos[0],
              observation.taxon,
              observation
            )}
          />
        ) )}
      </div>
    ) );
    if ( items.length < chunkSize ) {
      items.push(
        <a href={url} className="viewall">{ I18n.t( "view_all" ) }</a>
      );
    }

    return items;
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

RecentObservations.propTypes = {
  observations: PropTypes.array,
  showPhotoModal: PropTypes.func,
  url: PropTypes.string
};

export default RecentObservations;
