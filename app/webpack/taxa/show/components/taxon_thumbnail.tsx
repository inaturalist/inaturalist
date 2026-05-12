import React from "react";
import _ from "lodash";
import CoverImage from "../../../shared/components/cover_image";
import SplitTaxon from "../../../shared/components/split_taxon";
import { urlForTaxon as utilUrlForTaxon } from "../../shared/util";

interface Photo {
  photoUrl?: ( size: string ) => string;
  medium_url?: string;
  square_url?: string;
}

interface Taxon {
  id: number;
  defaultPhoto?: Photo;
  default_photo?: Photo;
  iconic_taxon_name?: string;
  [key: string]: unknown;
}

interface Config {
  currentUser?: unknown;
}

interface TaxonThumbnailProps {
  taxon: Taxon;
  className?: string;
  badgeText?: React.ReactNode;
  badgeTip?: string;
  height?: number;
  truncate?: number;
  onClick?: ( e: React.MouseEvent ) => boolean | void;
  captionForTaxon?: ( taxon: Taxon ) => React.ReactNode;
  urlForTaxon?: ( taxon: Taxon ) => string;
  overlay?: React.ReactNode;
  config?: Config;
  noInactive?: boolean;
}

const TaxonThumbnail = ( {
  taxon,
  className,
  badgeText,
  badgeTip,
  height,
  truncate,
  onClick,
  captionForTaxon,
  urlForTaxon = utilUrlForTaxon,
  overlay,
  config = {},
  noInactive
}: TaxonThumbnailProps ) => {
  let mediumURL: string | undefined;
  let squareURL: string | undefined;
  if ( taxon.defaultPhoto && _.isFunction( taxon.defaultPhoto.photoUrl ) ) {
    mediumURL = taxon.defaultPhoto.photoUrl( "medium" );
    squareURL = taxon.defaultPhoto.photoUrl( "square" );
  } else if ( _.isObject( taxon.default_photo ) ) {
    mediumURL = taxon.default_photo.medium_url;
    squareURL = taxon.default_photo.square_url;
  }

  const img = mediumURL ? (
    <CoverImage
      src={mediumURL}
      low={squareURL}
      height={height}
      className="photo"
    />
  ) : (
    <div className="photo" style={{ height, lineHeight: height ? `${height}px` : undefined }}>
      <i
        className={
          `icon-iconic-${taxon.iconic_taxon_name ? taxon.iconic_taxon_name.toLowerCase( ) : "unknown"}`
        }
      />
    </div>
  );

  const badge = badgeText ? (
    <span className={`badge ${badgeTip ? "with-tip" : ""}`} title={badgeTip}>
      { badgeText }
    </span>
  ) : null;

  const elementClassName = [
    "TaxonThumbnail thumbnail d-flex flex-column",
    className
  ].filter( Boolean ).join( " " );

  return (
    <div key={`similar-taxon-thumbnail-${taxon.id}`} className={elementClassName}>
      { badge }
      <a href={urlForTaxon( taxon )} onClick={onClick}>{ img }</a>
      { overlay && <div className="overlay">{ overlay }</div> }
      <div className="caption d-flex flex-column flex-grow-1 justify-content-between">
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
};

export default TaxonThumbnail;
