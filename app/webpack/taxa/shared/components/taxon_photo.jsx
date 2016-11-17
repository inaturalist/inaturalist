import React, { PropTypes } from "react";
import SplitTaxon from "../../../shared/components/split_taxon";
import CoverImage from "../../../shared/components/cover_image";
import { urlForTaxon, urlForTaxonPhotos } from "../../shared/util";

const TaxonPhoto = ( {
  photo,
  taxon,
  observation,
  width,
  height,
  showTaxonPhotoModal,
  className
} ) => (
  <div
    className={`TaxonPhoto ${className}`}
    style={{ width }}
  >
    <div className="photo-hover">
      <div className="actions">
        <button
          className="btn btn-link"
          onClick={ e => {
            e.preventDefault( );
            showTaxonPhotoModal( photo, taxon, observation );
            return false;
          } }
        >
          <i className="fa fa-search-plus"></i>
          { I18n.t( "enlarge" ) }
        </button>
        <a
          href={urlForTaxonPhotos( taxon )}
          className="btn btn-link"
        >
          <i className="fa fa-picture-o"></i>
          { I18n.t( "view_all" ) }
        </a>
      </div>
      <div className="photo-taxon">
        <SplitTaxon taxon={taxon} noParens url={urlForTaxon( taxon )} />
        <a href={urlForTaxon( taxon )} className="btn btn-link">
          <i className="fa fa-info-circle"></i>
        </a>
      </div>
    </div>
    <CoverImage
      src={ photo.photoUrl( "medium" ) }
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
  className: PropTypes.string
};

export default TaxonPhoto;
