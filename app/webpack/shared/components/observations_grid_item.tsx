import React from "react";
import SplitTaxon from "./split_taxon";
import UserImage from "./user_image";

interface ObsPhoto {
  id: number;
  photoUrl: ( size: string ) => string;
  attribution?: string;
}

interface Observation {
  id: number;
  reviewedByCurrentUser?: boolean;
  photo: ( size?: string ) => string | null;
  photos?: ObsPhoto[];
  hasPhotos: ( ) => boolean;
  hasMedia: ( ) => boolean;
  hasSounds: ( ) => boolean;
  user: unknown;
  taxon?: unknown;
}

interface ObservationsGridItemProps {
  observation: Observation;
  onObservationClick?: ( obs: Observation ) => void;
  before?: React.ReactElement;
  controls?: React.ReactElement | null;
  showMagnifier?: boolean;
  linkTarget?: string;
  splitTaxonOptions?: Record<string, unknown>;
  user?: unknown;
  showAllPhotosPreview?: boolean;
  photoSize?: string;
}

const ObservationsGridItem = ( {
  observation: o,
  onObservationClick,
  before,
  controls,
  showMagnifier,
  linkTarget = "_self",
  splitTaxonOptions = {},
  user,
  showAllPhotosPreview,
  photoSize = "small"
}: ObservationsGridItemProps ) => {
  let wrapperClass = "thumbnail borderless ObservationsGridItem d-flex flex-column";
  if ( o.reviewedByCurrentUser ) {
    wrapperClass += " reviewed";
  }
  return (
    <div className={wrapperClass}>
      { before }
      <a
        href={`/observations/${o.id}`}
        style={{
          backgroundImage: o.photo( ) ? `url( '${o.photo( photoSize )}' )` : ""
        }}
        target={linkTarget}
        className={`media ${o.hasPhotos( ) ? "photo" : ""} ${o.hasMedia( ) ? "" : "iconic"} ${o.hasSounds( ) ? "sound" : ""}`}
        onClick={( e ) => {
          if ( typeof onObservationClick !== "function" ) {
            return true;
          }
          e.preventDefault( );
          onObservationClick( o );
          return false;
        }}
      >
        <i className="icon icon-iconic-unknown" />
        <i className="sound-icon fa fa-volume-up" />
        { showMagnifier ? (
          <div className="magnifier">
            <i className="fa fa-search" />
          </div>
        ) : null }
        { o.photos && o.photos.length > 1 && (
          <span
            className="photo-count"
            title={I18n.t( "x_photos", { count: o.photos.length } )}
          >
            { o.photos.length > 9 ? "+" : o.photos.length }
          </span>
        ) }
        { showAllPhotosPreview && o.photos && o.photos.length > 1 && (
          <div className="all-photos-preview">
            { o.photos.slice( 0, 4 ).map( p => (
              <img
                key={`all-photos-preview-${o.id}-${p.id}`}
                src={p.photoUrl( "square" )}
                alt={I18n.t( "photo_attribution", { attribution: p.attribution } )}
              />
            ) ) }
          </div>
        ) }
      </a>
      <div className="caption flex-grow-1">
        <UserImage user={o.user} linkTarget={linkTarget} />
        <SplitTaxon
          {...splitTaxonOptions}
          taxon={o.taxon}
          user={user}
          url={`/observations/${o.id}`}
          target={linkTarget}
        />
        <div className="controls">
          { controls }
        </div>
      </div>
    </div>
  );
};

export default ObservationsGridItem;
