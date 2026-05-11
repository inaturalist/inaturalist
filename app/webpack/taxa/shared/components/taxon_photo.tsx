import React, { useEffect, useImperativeHandle, useRef } from "react";
import PropTypes from "prop-types";
import CoverImage from "../../../shared/components/cover_image";
import SplitTaxon from "../../../shared/components/split_taxon";
import { urlForTaxon } from "../util";

// TODO
// interface Photo {
//   photoUrl: (size: string) => string;
// }

// interface Taxon {

// }

// interface Observation {
  
// }

// interface Config {

// }

// interface TaxonPhotoProps {
//   photo: any,
//   taxon: any,
//   showTaxonPhotoModal?: () => void,
//   width?: number,
//   height?: number,
//   observation?: any,
//   className?: string,
//   size?: string,
//   backgroundSize?: string,
//   backgroundPosition?: string,
//   showTaxon?: boolean,
//   linkTaxon?: boolean,
//   onClickTaxon?: () => void,
//   config?: any,
//   children?: ReactNode
// }

// TODO: fix prop types
const TaxonPhoto = React.forwardRef<HTMLDivElement>( ( props: any, ref ) => {
  const innerRef = useRef<HTMLDivElement>(null);

  useImperativeHandle(ref, () => innerRef.current);

  useEffect(() => {
    if (innerRef.current) {
      console.log("clientWidth: ", innerRef.current.clientWidth);
    }
  }, [] );

  const {
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
  } = props;

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
  return (
    <div
      className={`TaxonPhoto ${className} carousel-item`}
      key={`TaxonPhoto-taxon-${taxon.id}-photo-${photo.id}`}
      ref={innerRef}
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
        size={size}
        height={height}
        backgroundSize={backgroundSize}
        backgroundPosition={backgroundPosition}
      />
    </div>
  );
} );

// TaxonPhoto.propTypes = {
//   photo: PropTypes.object.isRequired,
//   taxon: PropTypes.object.isRequired,
//   showTaxonPhotoModal: PropTypes.func.isRequired,
//   width: PropTypes.number,
//   height: PropTypes.number,
//   observation: PropTypes.object,
//   className: PropTypes.string,
//   size: PropTypes.string,
//   backgroundSize: PropTypes.string,
//   backgroundPosition: PropTypes.string,
//   showTaxon: PropTypes.bool,
//   linkTaxon: PropTypes.bool,
//   onClickTaxon: PropTypes.func,
//   config: PropTypes.object,
//   ref: PropTypes.bool
// };

// TaxonPhoto.defaultProps = {
//   size: "medium",
//   config: {}
// };

export default TaxonPhoto;
