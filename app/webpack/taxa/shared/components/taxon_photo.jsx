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
  backgroundSize,
  showTaxon,
  linkTaxon,
  onClickTaxon
} ) => {
  let photoTaxon;
  if ( showTaxon ) {
    photoTaxon = <div className="photo-taxon"><SplitTaxon taxon={taxon} noParens /></div>;
    if ( linkTaxon ) {
      photoTaxon = (
        <div className="photo-taxon">
          <SplitTaxon
            taxon={taxon}
            noParens
            url={urlForTaxon( taxon )}
            onClick={ e => {
              if ( !onClickTaxon ) return true;
              if ( e.metaKey || e.ctrlKey ) return true;
              e.preventDefault( );
              onClickTaxon( taxon );
              return false;
            } }
          />
          <a href={urlForTaxon( taxon )} className="btn btn-link info-link">
            <i className="fa fa-info-circle"></i>
          </a>
        </div>
      );
    }
  }
  const style = { width, maxWidth: 2 * width };
  return (
    <div
      className={`TaxonPhoto ${className}`}
      style={ style }
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
        { photoTaxon }
      </div>
      <CoverImage
        src={ photo.photoUrl( size ) || photo.photoUrl( "small" ) }
        low={ photo.photoUrl( "small" ) }
        height={height}
        backgroundSize={backgroundSize}
      />
    </div>
  );
};

TaxonPhoto.propTypes = {
  photo: PropTypes.object.isRequired,
  taxon: PropTypes.object.isRequired,
  showTaxonPhotoModal: PropTypes.func.isRequired,
  width: PropTypes.number,
  height: PropTypes.number.isRequired,
  observation: PropTypes.object,
  className: PropTypes.string,
  size: PropTypes.string,
  backgroundSize: PropTypes.string,
  showTaxon: PropTypes.bool,
  linkTaxon: PropTypes.bool,
  onClickTaxon: PropTypes.func
};

TaxonPhoto.defaultProps = {
  size: "medium"
};

export default TaxonPhoto;
