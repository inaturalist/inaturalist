import React from "react";
import CoverImage from "./cover_image";
import SplitTaxon from "./split_taxon";
import css from "./taxon_thumbnail.module.css";
import type { Taxon, Config } from "../types";
import { urlForTaxon as baseUrlForTaxon } from "../../taxa/shared/util";

// baseUrlForTaxon returns `string | null`; coerce to the prop contract
const defaultUrlForTaxon = ( taxon: Taxon ): string | undefined => (
  baseUrlForTaxon( taxon ) || undefined
);

export interface TaxonThumbnailBadge {
  text: React.ReactNode;
  linkUrl?: string;
  tip?: string;
}

export interface TaxonThumbnailProps {
  taxon: Taxon;
  width?: number;
  className?: string;
  overlay?: React.ReactNode;
  noInactive?: boolean;
  badge?: TaxonThumbnailBadge;
  onClick?: ( e: React.MouseEvent ) => void;
  captionForTaxon?: ( taxon: Taxon ) => React.ReactNode;
  urlForTaxon?: ( taxon: Taxon ) => string | undefined;
  config?: Config;
}

const TaxonThumbnail = ( {
  taxon,
  width,
  className,
  overlay,
  noInactive,
  badge,
  onClick,
  captionForTaxon,
  urlForTaxon = defaultUrlForTaxon,
  config = {}
}: TaxonThumbnailProps ) => {
  let mediumURL: string | undefined;
  let squareURL: string | undefined;
  if ( taxon.defaultPhoto && typeof taxon.defaultPhoto.photoUrl === "function" ) {
    mediumURL = taxon.defaultPhoto.photoUrl( "medium" );
    squareURL = taxon.defaultPhoto.photoUrl( "square" );
  } else if ( taxon.default_photo && typeof taxon.default_photo === "object" ) {
    mediumURL = taxon.default_photo.medium_url;
    squareURL = taxon.default_photo.square_url;
  }

  const wrapperStyle: React.CSSProperties | undefined = width
    ? { "--taxon-thumbnail-width": `${width}px` } as React.CSSProperties
    : undefined;

  return (
    <div
      className={`TaxonThumbnail ${css["taxon-thumbnail"]}${className ? ` ${className}` : ""}`}
      style={wrapperStyle}
    >
      { badge && (
        <span className={css.badge} title={badge.tip}>
          { badge.linkUrl ? <a href={badge.linkUrl}>{ badge.text }</a> : badge.text }
        </span>
      ) }
      <a href={urlForTaxon( taxon )} onClick={onClick} className={css.photo}>
        { mediumURL ? (
          <CoverImage src={mediumURL} low={squareURL} />
        ) : (
          <i
            className={
              `icon-iconic-${taxon.iconic_taxon_name ? taxon.iconic_taxon_name.toLowerCase( ) : "unknown"}`
            }
          />
        ) }
        { overlay && <div className={css.overlay}>{ overlay }</div> }
      </a>
      <div className={css.caption}>
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
};

export default TaxonThumbnail;
