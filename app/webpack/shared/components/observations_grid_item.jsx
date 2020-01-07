import React from "react";
import PropTypes from "prop-types";
import SplitTaxon from "./split_taxon";
import UserImage from "./user_image";

const ObservationsGridItem = ( {
  observation: o,
  onObservationClick,
  before,
  controls,
  showMagnifier,
  linkTarget,
  splitTaxonOptions,
  user,
  showAllPhotosPreview,
  photoSize
} ) => {
  let wrapperClass = "thumbnail borderless ObservationsGridItem";
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
        onClick={function ( e ) {
          if ( typeof ( onObservationClick ) !== "function" ) {
            return true;
          }
          e.preventDefault();
          onObservationClick( o );
          return false;
        }}
      >
        <i className={`icon icon-iconic-${"unknown"}`} />
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
      <div className="caption">
        <UserImage user={o.user} linkTarget={linkTarget} />
        {
          <SplitTaxon
            {...splitTaxonOptions}
            taxon={o.taxon}
            user={user}
            url={`/observations/${o.id}`}
            target={linkTarget}
          />
        }
        <div className="controls">
          { controls }
        </div>
      </div>
    </div>
  );
};

ObservationsGridItem.propTypes = {
  observation: PropTypes.object.isRequired,
  onObservationClick: PropTypes.func,
  before: PropTypes.element,
  controls: PropTypes.element,
  showMagnifier: PropTypes.bool,
  linkTarget: PropTypes.string,
  splitTaxonOptions: PropTypes.object,
  user: PropTypes.object,
  showAllPhotosPreview: PropTypes.bool,
  photoSize: PropTypes.string
};

ObservationsGridItem.defaultProps = {
  linkTarget: "_self",
  splitTaxonOptions: {},
  photoSize: "small"
};

export default ObservationsGridItem;
