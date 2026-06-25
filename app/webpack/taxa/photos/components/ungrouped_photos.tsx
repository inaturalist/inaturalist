import React from "react";
import InfiniteScroll from "react-infinite-scroller";
import ObservationPhotos from "./observation_photos";
import type { Config, Place } from "../../../shared/types";
import type { ObservationPhoto, ShowTaxonPhotoModal } from "./types";

interface UngroupedPhotosProps {
  observationPhotos?: ObservationPhoto[];
  hasMorePhotos?: boolean;
  loadMorePhotos: () => void;
  place?: Place;
  layout: string;
  showTaxonPhotoModal: ShowTaxonPhotoModal;
  config?: Config;
}

// The flat, infinitely-scrolling photo list shown when no grouping is active.
// `observationPhotos === undefined` means the first page is still loading;
// `[]` means the request finished with no results.
const UngroupedPhotos = ( {
  observationPhotos,
  hasMorePhotos,
  loadMorePhotos,
  place,
  layout,
  showTaxonPhotoModal,
  config
}: UngroupedPhotosProps ) => {
  const loader = (
    <div key="photo-browser-loader" className="loading">
      <i className="fa fa-refresh fa-spin" />
    </div>
  );
  const noObsNotice = (
    <div key="photo-browser-no-obs-notice" className="nocontent text-muted">
      { I18n.t( place ? "no_observations_from_this_place_yet" : "no_observations_yet" ) }
    </div>
  );
  return (
    <InfiniteScroll
      loadMore={( ) => loadMorePhotos( )}
      hasMore={hasMorePhotos}
      className="photos"
      loader={loader}
    >
      { observationPhotos && observationPhotos.length === 0 ? noObsNotice : null }
      { observationPhotos ? null : loader }
      <ObservationPhotos
        observationPhotos={observationPhotos}
        layout={layout}
        showTaxonPhotoModal={showTaxonPhotoModal}
        config={config}
      />
    </InfiniteScroll>
  );
};

export default UngroupedPhotos;
