import React, { useImperativeHandle, useRef } from "react";
import CoverImage from "./cover_image";
import SplitTaxon from "./split_taxon";
import css from "./taxon_photo.module.css";

const classes = {
  taxonPhoto: css["taxon-photo"],
  photoHover: css["taxon-photo__photo-hover"],
  modalBtn: css["taxon-photo__modal-btn"],
  taxonLabel: css["taxon-photo__taxon-label"],
  infoLink: css["taxon-photo__info-link"]
};

const urlForTaxon = ( t: { id: number; name: string } | null ) => (
  t ? `/taxa/${t.id}-${t.name.replace( /[^a-zA-Z0-9]/g, "-" )}` : null
);

export interface Photo {
  id: number;
  photoUrl: ( size: string ) => string;
}

export interface Taxon {
  id: number;
  name: string;
  [key: string]: unknown;
}

export interface Observation {
  id: number;
  [key: string]: unknown;
}

export interface TaxonPhotoProps {
  photo: Photo;
  taxon: Taxon;
  showTaxonPhotoModal: ( photo: Photo, taxon: Taxon, observation?: Observation ) => void;
  observation?: Observation;
  className?: string;
  size?: string;
  width?: number;
  height?: number;
  backgroundSize?: string;
  backgroundPosition?: string;
  showTaxon?: boolean;
  linkTaxon?: boolean;
  onClickTaxon?: ( taxon: Taxon ) => void;
  config?: { currentUser?: unknown; [key: string]: unknown };
}

const TaxonPhoto = React.forwardRef<HTMLDivElement, TaxonPhotoProps>( ( props, ref ) => {
  const innerRef = useRef<HTMLDivElement>( null );
  useImperativeHandle( ref, ( ) => innerRef.current! );

  const {
    photo,
    taxon,
    observation,
    showTaxonPhotoModal,
    className,
    size = "medium",
    width,
    height,
    backgroundSize,
    backgroundPosition,
    showTaxon,
    linkTaxon,
    onClickTaxon,
    config = {}
  } = props;

  let taxonLabel;
  if ( showTaxon ) {
    taxonLabel = (
      <div className={classes.taxonLabel}>
        <SplitTaxon taxon={taxon} noParens />
      </div>
    );
    if ( linkTaxon ) {
      taxonLabel = (
        <div className={classes.taxonLabel}>
          <SplitTaxon
            taxon={taxon}
            noParens
            url={urlForTaxon( taxon )}
            onClick={( e: React.MouseEvent ) => {
              if ( !onClickTaxon ) return true;
              if ( e.metaKey || e.ctrlKey ) return true;
              e.preventDefault( );
              onClickTaxon( taxon );
              return false;
            }}
            user={config.currentUser}
          />
          <a href={urlForTaxon( taxon ) ?? undefined} className={classes.infoLink} aria-label={I18n.t( "view_taxon" )}>
            <i className="fa fa-info-circle" />
          </a>
        </div>
      );
    }
  }

  return (
    <div
      className={`TaxonPhoto ${classes.taxonPhoto}${className ? ` ${className}` : ""}`}
      ref={innerRef}
      style={width
        ? { width, maxWidth: 2 * width, height: "auto" }
        : undefined}
    >
      <div className={classes.photoHover}>
        <button
          type="button"
          className={classes.modalBtn}
          aria-label={I18n.t( "view_photo" )}
          onClick={e => {
            e.preventDefault( );
            showTaxonPhotoModal( photo, taxon, observation );
            return false;
          }}
        >
          <i className="fa fa-search-plus" />
        </button>
        { taxonLabel }
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
} );

export default TaxonPhoto;
