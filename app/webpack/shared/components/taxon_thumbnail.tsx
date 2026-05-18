import React, { useImperativeHandle, useRef } from "react";
import CoverImage from "./cover_image";
import SplitTaxon from "./split_taxon";
import css from "./taxon_thumbnail.module.css";


const defaultUrlForTaxon = ( t: { id: number; name: string } ) => (
  `/taxa/${t.id}-${t.name.replace( /[^a-zA-Z0-9]/g, "-" )}`
);

export interface DefaultPhoto {
  photoUrl: ( size: string ) => string;
}

export interface RawPhoto {
  medium_url: string;
  square_url: string;
}

export interface Taxon {
  id: number;
  name: string;
  defaultPhoto?: DefaultPhoto;
  default_photo?: RawPhoto;
  iconic_taxon_name?: string;
  [key: string]: unknown;
}

export interface TaxonThumbnailProps {
  taxon: Taxon;
  width?: number;
  height?: number;
  className?: string;
  overlay?: React.ReactNode;
  noInactive?: boolean;
  onClick?: ( e: React.MouseEvent ) => void;
  captionForTaxon?: ( taxon: Taxon ) => React.ReactNode;
  urlForTaxon?: ( taxon: Taxon ) => string;
  config?: { currentUser?: unknown; [key: string]: unknown };
}

const TaxonThumbnail = React.forwardRef<HTMLDivElement, TaxonThumbnailProps>( ( props, ref ) => {
  const innerRef = useRef<HTMLDivElement>( null );
  useImperativeHandle( ref, ( ) => innerRef.current! );

  const {
    taxon,
    width,
    height,
    className,
    overlay,
    noInactive,
    onClick,
    captionForTaxon,
    urlForTaxon = defaultUrlForTaxon,
    config = {}
  } = props;

  let mediumURL: string | undefined;
  let squareURL: string | undefined;
  if ( taxon.defaultPhoto && typeof taxon.defaultPhoto.photoUrl === "function" ) {
    mediumURL = taxon.defaultPhoto.photoUrl( "medium" );
    squareURL = taxon.defaultPhoto.photoUrl( "square" );
  } else if ( taxon.default_photo && typeof taxon.default_photo === "object" ) {
    mediumURL = taxon.default_photo.medium_url;
    squareURL = taxon.default_photo.square_url;
  }

  let wrapperStyle: React.CSSProperties | undefined;
  if ( height ) {
    wrapperStyle = { width: "100%", height, aspectRatio: "unset" };
  } else if ( width ) {
    wrapperStyle = { "--taxon-thumbnail-width": `${width}px` } as React.CSSProperties;
  }

  return (
    <div
      ref={innerRef}
      className={`TaxonThumbnail ${css["taxon-thumbnail"]}${className ? ` ${className}` : ""}`}
      style={wrapperStyle}
    >
      <a href={urlForTaxon( taxon )} onClick={onClick} className={css["taxon-thumbnail__photo"]}>
        { mediumURL ? (
          <CoverImage src={mediumURL} low={squareURL} />
        ) : (
          <i
            className={
              `icon-iconic-${taxon.iconic_taxon_name ? taxon.iconic_taxon_name.toLowerCase( ) : "unknown"}`
            }
          />
        ) }
        { overlay && <div className={css["taxon-thumbnail__overlay"]}>{ overlay }</div> }
      </a>
      <div className={css["taxon-thumbnail__caption"]}>
        <SplitTaxon
          taxon={taxon}
          url={urlForTaxon( taxon )}
          noParens
          onClick={onClick}
          user={config.currentUser}
          noInactive={noInactive}
        />
        { captionForTaxon ? captionForTaxon( taxon ) : null }
      </div>
    </div>
  );
} );

export default TaxonThumbnail;
