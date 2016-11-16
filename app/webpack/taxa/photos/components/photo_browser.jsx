import React, { PropTypes } from "react";
import TaxonPhoto from "../../shared/components/taxon_photo";

const PhotoBrowser = ( { observationPhotos, showTaxonPhotoModal } ) => (
  <div className="PhotoBrowser">
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
            observationPhotos.observation
          ) }
        />
      );
    } ) }
  </div>
);

PhotoBrowser.propTypes = {
  observationPhotos: PropTypes.array.isRequired,
  showTaxonPhotoModal: PropTypes.func.isRequired
};

PhotoBrowser.defaultProps = {
  observationPhotos: []
};

export default PhotoBrowser;
