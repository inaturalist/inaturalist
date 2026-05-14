import React, { useImperativeHandle, useRef } from "react";
import { OverlayTrigger, Tooltip } from "react-bootstrap";
import CoverImage from "./cover_image";
import SplitTaxon from "./split_taxon";
import css from "./taxon_thumbnail.module.css";

const classes = {
  taxonThumbnail: css["taxon-thumbnail"],
  photo: css["taxon-thumbnail__photo"],
  badge: css["taxon-thumbnail__badge"],
  badgeWithTip: css["taxon-thumbnail__badge--with-tip"],
  overlay: css["taxon-thumbnail__overlay"],
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
  className?: string;
  badgeText?: React.ReactNode;
  badgeTip?: string;
  truncate?: number;
  onClick?: ( e: React.MouseEvent ) => void;
  captionForTaxon?: ( taxon: Taxon ) => React.ReactNode;
  urlForTaxon?: ( taxon: Taxon ) => string;
  overlay?: React.ReactNode;
  config?: { currentUser?: unknown; [key: string]: unknown };
  noInactive?: boolean;
  style?: React.CSSProperties;
}

const TaxonThumbnail = React.forwardRef<HTMLDivElement, TaxonThumbnailProps>( ( props, ref ) => {
  const innerRef = useRef<HTMLDivElement>( null );
  useImperativeHandle( ref, ( ) => innerRef.current! );

  const {
    taxon,
    className,
    badgeText,
    badgeTip,
    truncate,
    onClick,
    captionForTaxon,
    urlForTaxon = defaultUrlForTaxon,
    overlay,
    config = {},
    noInactive,
    style
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

  let badge: React.ReactNode;
  if ( badgeText ) {
    const badgeClassName = `${classes.badge}${badgeTip ? ` ${classes.badgeWithTip}` : ""}`;
    const badgeSpan = <span className={badgeClassName}>{ badgeText }</span>;
    if ( badgeTip ) {
      const snakeText = String( badgeText ).toLowerCase( ).replace( /\s+/g, "_" );
      badge = (
        <OverlayTrigger
          placement="top"
          overlay={(
            <Tooltip id={`taxon-thumbnail-badge-${taxon.id}-${snakeText}`}>
              { badgeTip }
            </Tooltip>
          )}
        >
          { badgeSpan }
        </OverlayTrigger>
      );
    } else {
      badge = badgeSpan;
    }
  }

  const rootClassName = `${classes.taxonThumbnail}${className ? ` ${className}` : ""}`;

  return (
    <div ref={innerRef} className={rootClassName} style={style}>
      { badge }
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
      { overlay && <div className={classes.overlay}>{ overlay }</div> }
      <div className={classes.caption}>
        <SplitTaxon
          taxon={taxon}
          url={urlForTaxon( taxon )}
          noParens
          truncate={truncate}
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
