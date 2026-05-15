import React, { useImperativeHandle, useRef } from "react";
import CoverImage from "./cover_image";
import SplitTaxon from "./split_taxon";
import css from "./taxon_thumbnail.module.css";

const classes = {
  taxonThumbnail: css["taxon-thumbnail"],
  photo: css["taxon-thumbnail__photo"],
  caption: css["taxon-thumbnail__caption"]
};

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

  return (
    <div
      ref={innerRef}
      className={`TaxonThumbnail ${classes.taxonThumbnail}`}
      style={width ? { "--taxon-thumbnail-width": `${width}px` } as React.CSSProperties : undefined}
    >
      <a href={urlForTaxon( taxon )} onClick={onClick} className={classes.photo}>
        { mediumURL ? (
          <CoverImage src={mediumURL} low={squareURL} />
        ) : (
          <i
            className={
              `icon-iconic-${taxon.iconic_taxon_name ? taxon.iconic_taxon_name.toLowerCase( ) : "unknown"}`
            }
          />
        ) }
      </a>
      <div className={classes.caption}>
        <SplitTaxon
          taxon={taxon}
          url={urlForTaxon( taxon )}
          noParens
          onClick={onClick}
          user={config.currentUser}
        />
        { captionForTaxon ? captionForTaxon( taxon ) : null }
      </div>
    </div>
  );
} );

export default TaxonThumbnail;
