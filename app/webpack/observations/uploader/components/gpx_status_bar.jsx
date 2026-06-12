import React from "react";
import PropTypes from "prop-types";
import { Glyphicon } from "react-bootstrap";
import _ from "lodash";

const GpxStatusBar = ( {
  gpxTrack,
  removeGpxTrack,
  applyGpxLocations
} ) => {
  if ( !gpxTrack ) return null;
  const matchCount = _.size( gpxTrack.matchedLocations );
  return (
    <div className="gpx-status-bar alert alert-info">
      <span className="gpx-info">
        <i className="fa fa-road" />
        { " " }
        <strong>{ gpxTrack.fileName }</strong>
        { " — " }
        { I18n.t( "gpx_x_trackpoints", { count: gpxTrack.points.length } ) }
        { matchCount > 0 && (
          <span>
            { " — " }
            { I18n.t( "gpx_x_observations_matched", { count: matchCount } ) }
          </span>
        ) }
      </span>
      <span className="gpx-actions">
        <button
          type="button"
          className="btn btn-xs btn-default"
          onClick={( ) => applyGpxLocations( { overrideExisting: true } )}
        >
          { I18n.t( "gpx_apply_to_all" ) }
        </button>
        <button
          type="button"
          className="btn btn-xs btn-default"
          onClick={removeGpxTrack}
        >
          <Glyphicon glyph="remove" />
          { " " }
          { I18n.t( "gpx_remove_track" ) }
        </button>
      </span>
    </div>
  );
};

GpxStatusBar.propTypes = {
  gpxTrack: PropTypes.object,
  removeGpxTrack: PropTypes.func,
  applyGpxLocations: PropTypes.func
};

export default GpxStatusBar;
