import _ from "lodash";
import React from "react";
import PropTypes from "prop-types";
import moment from "moment-timezone";
import CoverImage from "../../../shared/components/cover_image";
import SplitTaxon from "../../../shared/components/split_taxon";
import UserImage from "../../../shared/components/user_image";

const shortRelativeTime = I18n.t( "momentjs" ) ? I18n.t( "momentjs" ).shortRelativeTime : null;
if ( shortRelativeTime ) {
  moment.updateLocale( I18n.locale, { relativeTime: shortRelativeTime } );
}

const Observation = ( {
  observation,
  width,
  height,
  className,
  size,
  backgroundSize,
  config,
  hideUserIcon
} ) => {
  const observedDate = observation.time_observed_at || observation.observed_on;
  const identificationsCount = _.size( _.filter( observation.identifications, "current" ) );
  const caption = (
    <div className={`caption ${hideUserIcon ? "no-icon" : ""}`}>
      <SplitTaxon
        taxon={observation.taxon}
        noParens
        user={config.currentUser}
        url={`/observations/${observation.id}`}
        noInactive
      />
      { !hideUserIcon && ( <UserImage user={observation.user} /> ) }
      <div className="meta">
        { identificationsCount > 0 && (
          <span
            className="count identifications"
            title={
              I18n.t( "x_identifications", { count: identificationsCount } )
            }
          >
            <i className="icon-identification" />
            { identificationsCount }
          </span>
        ) }
        { observation.comments.length > 0 && (
          <span
            className="count comments"
            title={I18n.t( "x_comments", { count: observation.comments.length } )}
          >
            <i className="icon-chatbubble" />
            { observation.comments.length }
          </span>
        ) }
        { observedDate && (
          <span className="time" title={`${I18n.t( "observed_on" )} ${observedDate}`}>
            { moment( observedDate ).fromNow( ) }
          </span>
        ) }
      </div>
    </div>
  );
  const style = { width, maxWidth: 2 * width };
  let img;
  if ( observation.photos.length > 0 ) {
    const photo = observation.photos[0];
    img = (
      <CoverImage
        src={photo.photoUrl( size ) || photo.photoUrl( "small" )}
        low={photo.photoUrl( "small" )}
        height={height}
        backgroundSize={backgroundSize}
      />
    );
  } else if ( observation.hasSounds( ) ) {
    img = (
      <div className="photo" style={{ height, lineHeight: `${height}px` }}>
        <i className="sound-icon fa fa-volume-up" />
      </div>
    );
  } else {
    const iconicTaxonClass = observation.taxon && observation.taxon.iconic_taxon_name
      ? observation.taxon.iconic_taxon_name.toLowerCase( ) : "unknown";
    img = (
      <div className="photo" style={{ height, lineHeight: `${height}px` }}>
        <i className={`icon-iconic-${iconicTaxonClass}`} />
      </div>
    );
  }
  return (
    <div
      className="ObservationsGridCell"
      style={style}
      key={`observation-grid-cell-${observation.id}`}
    >
      <div
        className={`Observation ${className}`}
      >
        <a
          href={`/observations/${observation.id}`}
          className={`media ${observation.hasPhotos( ) ? "photo" : ""} ${observation.hasMedia( ) ? "" : "iconic"} ${observation.hasSounds( ) ? "sound" : ""}`}
        >
          { img }
        </a>
        { observation.quality_grade === "research" && (
          <div
            className="quality research"
            title={I18n.t( "research_grade" )}
            dangerouslySetInnerHTML={
              { __html: I18n.t( "research_grade_short_html" ) }
            }
          />
        ) }
        { observation.hasSounds( ) && observation.hasPhotos( ) && (
          <span className="with-sounds">
            <i className="sound-icon fa fa-volume-up" />
          </span>
        ) }
        { caption }
      </div>
    </div>
  );
};

Observation.propTypes = {
  observation: PropTypes.object.isRequired,
  width: PropTypes.number,
  height: PropTypes.number.isRequired,
  className: PropTypes.string,
  size: PropTypes.string,
  backgroundSize: PropTypes.string,
  hideUserIcon: PropTypes.bool,
  config: PropTypes.object
};

Observation.defaultProps = {
  size: "medium",
  config: {}
};

export default Observation;
