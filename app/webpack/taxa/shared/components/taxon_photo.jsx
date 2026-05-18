import React from "react";
import PropTypes from "prop-types";
import CoverImage from "../../../shared/components/cover_image";
import SplitTaxon from "../../../shared/components/split_taxon";
import { urlForTaxon } from "../util";

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
  backgroundPosition,
  showTaxon,
  linkTaxon,
  onClickTaxon,
  config
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
            onClick={e => {
              if ( !onClickTaxon ) return true;
              if ( e.metaKey || e.ctrlKey ) return true;
              e.preventDefault( );
              onClickTaxon( taxon );
              return false;
            }}
            user={config.currentUser}
          />
          <a href={urlForTaxon( taxon )} className="btn btn-link info-link">
            <i className="fa fa-info-circle" />
          </a>
        </div>
      );
    }
  }
  let style = {};
  if ( width ) {
    style = { width, maxWidth: 2 * width };
  }
  return (
    <div
      className={`TaxonPhoto ${className}`}
      style={style}
      key={`TaxonPhoto-taxon-${taxon.id}-photo-${photo.id}`}
    >
      <div className="photo-hover">
        <button
          type="button"
          className="btn btn-link modal-link"
          onClick={e => {
            e.preventDefault( );
            showTaxonPhotoModal( photo, taxon, observation );
            return false;
          }}
        >
          <i className="fa fa-search-plus" />
        </button>
        { photoTaxon }
      </div>
      <CoverImage
        src={photo.photoUrl( size ) || photo.photoUrl( "small" )}
        low={photo.photoUrl( "small" )}
        height={height}
        backgroundSize={backgroundSize}
        backgroundPosition={backgroundPosition}
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
  backgroundPosition: PropTypes.string,
  showTaxon: PropTypes.bool,
  linkTaxon: PropTypes.bool,
  onClickTaxon: PropTypes.func,
  config: PropTypes.object
};

TaxonPhoto.defaultProps = {
  size: "medium",
  config: {}
};

export default TaxonPhoto;
