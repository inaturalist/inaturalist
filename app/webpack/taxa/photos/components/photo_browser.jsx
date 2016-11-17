import React, { PropTypes } from "react";
import InfiniteScroll from "react-infinite-scroller";
import TaxonPhoto from "../../shared/components/taxon_photo";

const PhotoBrowser = ( {
  observationPhotos,
  showTaxonPhotoModal,
  loadMorePhotos,
  hasMorePhotos
} ) => (
  <div className="PhotoBrowser">
    <InfiniteScroll
      loadMore={( ) => loadMorePhotos( )}
      hasMore={ hasMorePhotos }
      loader={
        <div className="loading">
          <i className="fa fa-refresh fa-spin"></i> { I18n.t( "loading" ) }
        </div>
      }
    >
      { observationPhotos.map( observationPhoto => {
        const itemDim = 170;
        return (
          <TaxonPhoto
            key={`taxon-photo-${observationPhoto.photo.id}`}
            photo={observationPhoto.photo}
            taxon={observationPhoto.observation.taxon}
            observation={observationPhoto.observation}
            photoHeight={itemDim}
            showTaxonPhotoModal={ ( ) => showTaxonPhotoModal(
              observationPhoto.photo,
              observationPhoto.observation.taxon,
              observationPhoto.observation
            ) }
          />
        );
      } ) }
    </InfiniteScroll>
  </div>
);

PhotoBrowser.propTypes = {
  observationPhotos: PropTypes.array.isRequired,
  showTaxonPhotoModal: PropTypes.func.isRequired,
  loadMorePhotos: PropTypes.func.isRequired,
  hasMorePhotos: PropTypes.bool
};

PhotoBrowser.defaultProps = {
  observationPhotos: []
};

export default PhotoBrowser;
