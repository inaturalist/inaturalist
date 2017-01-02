import React, { PropTypes } from "react";
import CoverImage from "../../../shared/components/cover_image";
import SplitTaxon from "../../../shared/components/split_taxon";
import { urlForTaxon } from "../../shared/util";

const TaxonPhoto = ( {
  photo,
  taxon,
  observation,
  width,
  height,
  showTaxonPhotoModal,
  className,
  size,
  showTaxon
} ) => (
  <div
    className={`TaxonPhoto ${className}`}
    style={{ width, maxWidth: 2 * width }}
  >
    <div className="photo-hover">
      <button
        className="btn btn-link modal-link"
        onClick={ e => {
          e.preventDefault( );
          showTaxonPhotoModal( photo, taxon, observation );
          return false;
        } }
      >
        <i className="fa fa-search-plus"></i>
      </button>
      { showTaxon ? (
        <div className="photo-taxon">
          <SplitTaxon taxon={taxon} noParens url={urlForTaxon( taxon )} />
          <a href={urlForTaxon( taxon )} className="btn btn-link info-link">
            <i className="fa fa-info-circle"></i>
          </a>
        </div>
      ) : null }
    </div>
    <CoverImage
      src={ photo.photoUrl( size ) || photo.photoUrl( "small" ) }
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
  size: PropTypes.string,
  showTaxon: PropTypes.bool
};

TaxonPhoto.defaultProps = {
  size: "medium"
};

export default TaxonPhoto;
