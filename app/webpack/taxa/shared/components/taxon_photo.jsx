import React, { PropTypes } from "react";
import CoverImage from "../../../shared/components/cover_image";

const TaxonPhoto = ( {
  photo,
  taxon,
  observation,
  width,
  height,
  showTaxonPhotoModal,
  className,
  size
} ) => (
  <div
    className={`TaxonPhoto ${className}`}
    style={{ width, maxWidth: 2 * width }}
  >
    <div className="photo-hover">
      <button
        className="btn btn-link"
        onClick={ e => {
          e.preventDefault( );
          showTaxonPhotoModal( photo, taxon, observation );
          return false;
        } }
      >
        <i className="fa fa-search-plus"></i>
      </button>
    </div>
    <CoverImage
      src={ photo.photoUrl( size ) }
      low={ photo.photoUrl( "small" ) }
      height={height}
    />
  </div>
);

TaxonPhoto.propTypes = {
  photo: PropTypes.object.isRequired,
  taxon: PropTypes.object.isRequired,
  showTaxonPhotoModal: PropTypes.func.isRequired,
  width: PropTypes.number,
  height: PropTypes.number.isRequired,
  observation: PropTypes.object,
  className: PropTypes.string,
  size: PropTypes.string
};

TaxonPhoto.defaultProps = {
  size: "medium"
};

export default TaxonPhoto;
