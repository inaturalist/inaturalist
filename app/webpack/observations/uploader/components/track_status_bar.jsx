import React from "react";
import PropTypes from "prop-types";
import { Glyphicon, OverlayTrigger, Tooltip } from "react-bootstrap";
import _ from "lodash";

const MS_PER_MINUTE = 60 * 1000;

const TrackStatusBar = ( {
  gpsTrack,
  removeGpsTrack,
  applyTrackLocations,
  setTrackClockOffset
} ) => {
  if ( !gpsTrack ) return null;
  const matchCount = _.size( gpsTrack.matchedLocations );
  // Only re-match when the user is done typing, since every re-match can
  // move cards and trigger reverse geocoding
  const commitClockOffset = e => {
    const minutes = parseInt( e.target.value, 10 ) || 0;
    if ( minutes * MS_PER_MINUTE !== gpsTrack.clockOffsetMs ) {
      setTrackClockOffset( minutes * MS_PER_MINUTE );
    }
  };
  return (
    <div className="gps-track-status-bar alert alert-info">
      <span className="gps-track-info">
        <i className="fa fa-road" />
        { " " }
        <strong>{ gpsTrack.fileName }</strong>
        { " — " }
        { I18n.t( "gps_track_x_points", { count: gpsTrack.points.length } ) }
        { " — " }
        { I18n.t( "gps_track_x_observations_matched", { count: matchCount } ) }
        { gpsTrack.timeZone && (
          <span className="gps-track-time-zone">
            { " — " }
            { I18n.t( "gps_track_photo_times_in_zone", { time_zone: gpsTrack.timeZone } ) }
          </span>
        ) }
      </span>
      <span className="gps-track-actions">
        <label className="gps-track-clock-offset">
          { I18n.t( "gps_track_camera_clock_offset" ) }
          { " " }
          <input
            key={gpsTrack.fileName}
            type="number"
            step="1"
            className="form-control input-sm"
            defaultValue={Math.round( gpsTrack.clockOffsetMs / MS_PER_MINUTE )}
            onBlur={commitClockOffset}
            onKeyDown={e => {
              if ( e.key === "Enter" ) commitClockOffset( e );
            }}
          />
        </label>
        <OverlayTrigger
          placement="bottom"
          overlay={(
            <Tooltip id="gps-track-help">
              { I18n.t( "gps_track_help" ) }
            </Tooltip>
          )}
        >
          <i className="fa fa-question-circle gps-track-help" />
        </OverlayTrigger>
        <button
          type="button"
          className="btn btn-xs btn-default"
          onClick={( ) => applyTrackLocations( { overrideExisting: true } )}
        >
          { I18n.t( "gps_track_apply_to_all" ) }
        </button>
        <button
          type="button"
          className="btn btn-xs btn-default"
          onClick={removeGpsTrack}
        >
          <Glyphicon glyph="remove" />
          { " " }
          { I18n.t( "gps_track_remove" ) }
        </button>
      </span>
    </div>
  );
};

TrackStatusBar.propTypes = {
  gpsTrack: PropTypes.object,
  removeGpsTrack: PropTypes.func,
  applyTrackLocations: PropTypes.func,
  setTrackClockOffset: PropTypes.func
};

export default TrackStatusBar;
