import React, { PropTypes } from "react";
import CoverImage from "../../../shared/components/cover_image";
import SplitTaxon from "../../../shared/components/split_taxon";
import UserImage from "../../../shared/components/user_image";
import moment from "moment-timezone";

const shortRelativeTime = I18n.t( "momentjs" ) ? I18n.t( "momentjs" ).shortRelativeTime : null;
if ( shortRelativeTime ) {
  moment.locale( I18n.locale, { relativeTime: shortRelativeTime } );
}

const Observation = ( {
  observation,
  width,
  height,
  className,
  size,
  backgroundSize,
  config
} ) => {
  const observedDate = observation.time_observed_at || observation.observed_on;
  let caption = (
    <div className="caption">
      <SplitTaxon
        taxon={ observation.taxon }
        noParens
        user={ config.currentUser }
        url={ `/observations/${observation.id}` }
      />
      <UserImage user={ observation.user } />
      <div className="meta">
        { observation.non_owner_ids.length > 0 && (
          <span
            className="count identifications"
            title={
              I18n.t( "x_identifications", { count: observation.non_owner_ids.length } )
            }
          >
            <i className="icon-identification" />
            { observation.non_owner_ids.length }
          </span>
        ) }
        { observation.comments.length > 0 && (
          <span
            className="count comments"
            title={ I18n.t( "x_comments", { count: observation.comments.length } ) }
          >
            <i className="icon-chatbubble" />
            { observation.comments.length }
          </span>
        ) }
        { observedDate && (
          <span className="time" title={ `${I18n.t( "observed_on" )} ${observedDate}` }>
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
        src={ photo.photoUrl( size ) || photo.photoUrl( "small" ) }
        low={ photo.photoUrl( "small" ) }
        height={ height }
        backgroundSize={ backgroundSize }
      />
    );
  } else {
    const iconicTaxonClass = observation.taxon && observation.taxon.iconic_taxon_name ?
      observation.taxon.iconic_taxon_name.toLowerCase( ) : "unknown";
    img = (
      <div className="photo" style={{ height, lineHeight: `${height}px` }}>
        <i className={ `icon-iconic-${iconicTaxonClass}`} />
      </div>
    );
  }
  return (
    <div
      className="ObservationsGridCell"
      style={ style }
      key={ `observation-grid-cell-${observation.id}` }
    >
      <div
        className={`Observation ${className}`}
      >
        <a href={ `/observations/${observation.id}` }>
          { img }
        </a>
        { observation.quality_grade === "research" && (
          <div
            className="quality research"
            title={ I18n.t( "research_grade" ) }
            dangerouslySetInnerHTML={ { __html:
              I18n.t( "research_grade_short_html" )
            } }
          />
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
  showTaxon: PropTypes.bool,
  linkTaxon: PropTypes.bool,
  onClickTaxon: PropTypes.func,
  photoKey: PropTypes.string,
  config: PropTypes.object
};

Observation.defaultProps = {
  size: "medium",
  config: {}
};

export default Observation;
