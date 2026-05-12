import React, { useImperativeHandle, useRef } from "react";
import CoverImage from "../../../shared/components/cover_image";
import SplitTaxon from "../../../shared/components/split_taxon";
import { urlForTaxon } from "../util";

interface Photo {
  id: number;
  photoUrl: ( size: string ) => string;
}

interface Taxon {
  id: number;
  name: string;
  [key: string]: unknown;
}

interface Observation {
  id: number;
  [key: string]: unknown;
}

interface Config {
  currentUser?: unknown;
  [key: string]: unknown;
}

interface TaxonPhotoProps {
  photo: Photo;
  taxon: Taxon;
  showTaxonPhotoModal: ( photo: Photo, taxon: Taxon, observation?: Observation ) => void;
  width?: number;
  height?: number;
  observation?: Observation;
  className?: string;
  size?: string;
  backgroundSize?: string;
  backgroundPosition?: string;
  showTaxon?: boolean;
  linkTaxon?: boolean;
  onClickTaxon?: ( taxon: Taxon ) => void;
  config?: Config;
}

const TaxonPhoto = React.forwardRef<HTMLDivElement, TaxonPhotoProps>( ( props, ref ) => {
  const innerRef = useRef<HTMLDivElement>( null );

  useImperativeHandle( ref, ( ) => innerRef.current! );

  const {
    photo,
    taxon,
    observation,
    height,
    showTaxonPhotoModal,
    className,
    size = "medium",
    backgroundSize,
    backgroundPosition,
    showTaxon,
    linkTaxon,
    onClickTaxon,
    config = {}
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

export default TaxonPhoto;
