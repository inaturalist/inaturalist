import React, { Component } from "react";
import PropTypes from "prop-types";
import moment from "moment";
import { Button, Modal } from "react-bootstrap";
import { GARMIN_API_KEY_SETTINGS_URL } from "../../../shared/geotrack";
import {
  browserTimeZone,
  cardTimeItems,
  countItemsDuringActivity
} from "../models/track_matching";

function formatDuration( durationMs ) {
  if ( !Number.isFinite( durationMs ) ) return null;
  const totalMinutes = Math.round( durationMs / 60000 );
  const minutes = String( totalMinutes % 60 ).padStart( 2, "0" );
  return `${Math.floor( totalMinutes / 60 )}:${minutes}`;
}

class GarminImportModal extends Component {
  constructor( props ) {
    super( props );
    this.state = { apiKey: "" };
    this.onSubmitKey = this.onSubmitKey.bind( this );
  }

  onSubmitKey( e ) {
    e.preventDefault( );
    const { connectGarmin } = this.props;
    const { apiKey } = this.state;
    if ( !apiKey.trim( ) ) return;
    connectGarmin( apiKey );
    // Don't keep the key around once it's been exchanged
    this.setState( { apiKey: "" } );
  }

  renderKeyForm( ) {
    const { garmin } = this.props;
    const { apiKey } = this.state;
    return (
      <form onSubmit={this.onSubmitKey}>
        <p>{ I18n.t( "gps_track_garmin_key_help" ) }</p>
        <p>
          <a href={GARMIN_API_KEY_SETTINGS_URL} target="_blank" rel="noopener noreferrer">
            { I18n.t( "gps_track_garmin_get_key" ) }
          </a>
        </p>
        <div className="form-group">
          <label htmlFor="garmin-api-key">{ I18n.t( "gps_track_garmin_api_key" ) }</label>
          <input
            id="garmin-api-key"
            type="password"
            className="form-control"
            autoComplete="off"
            value={apiKey}
            onChange={e => this.setState( { apiKey: e.target.value } )}
          />
        </div>
        <Button
          type="submit"
          bsStyle="primary"
          disabled={garmin.loading || !apiKey.trim( )}
        >
          { garmin.loading ? I18n.t( "loading" ) : I18n.t( "gps_track_garmin_connect" ) }
        </Button>
      </form>
    );
  }

  renderActivities( ) {
    const {
      garmin,
      obsCards,
      files,
      importGarminActivity,
      loadGarminActivities
    } = this.props;
    const { activities } = garmin;
    if ( !activities ) {
      return <p>{ I18n.t( "loading" ) }</p>;
    }
    if ( activities.length === 0 ) {
      return <p>{ I18n.t( "gps_track_garmin_no_activities" ) }</p>;
    }
    const photoItems = cardTimeItems( obsCards, files, { timeZone: browserTimeZone( ) } );
    return (
      <div>
        <table className="table gps-track-garmin-activities">
          <tbody>
            { activities.map( activity => {
              const photoCount = countItemsDuringActivity( photoItems, activity );
              const distance = Number.isFinite( activity.distanceM )
                ? I18n.t( "gps_track_garmin_distance_km", {
                  distance: I18n.toNumber( activity.distanceM / 1000, { precision: 1 } )
                } )
                : null;
              const details = [
                moment( activity.startTimeMs ).format( "lll" ),
                formatDuration( activity.durationMs ),
                distance
              ].filter( Boolean ).join( " · " );
              return (
                <tr key={activity.id}>
                  <td>
                    <div className="gps-track-garmin-name">
                      { activity.name || activity.type }
                    </div>
                    <div className="text-muted">{ details }</div>
                  </td>
                  <td className="gps-track-garmin-photos">
                    { photoCount > 0 && (
                      <span className="label label-success">
                        { I18n.t( "x_photos", { count: photoCount } ) }
                      </span>
                    ) }
                  </td>
                  <td className="text-right">
                    { activity.hasTrack ? (
                      <Button
                        bsSize="small"
                        bsStyle={photoCount > 0 ? "primary" : "default"}
                        disabled={garmin.importingId !== null}
                        onClick={( ) => importGarminActivity( activity )}
                      >
                        { garmin.importingId === activity.id
                          ? I18n.t( "loading" )
                          : I18n.t( "import" ) }
                      </Button>
                    ) : (
                      <span className="text-muted">{ I18n.t( "gps_track_garmin_no_gps" ) }</span>
                    ) }
                  </td>
                </tr>
              );
            } ) }
          </tbody>
        </table>
        { garmin.hasMore && (
          <Button
            bsStyle="link"
            disabled={garmin.loading}
            onClick={( ) => loadGarminActivities( { more: true } )}
          >
            { garmin.loading ? I18n.t( "loading" ) : I18n.t( "show_more" ) }
          </Button>
        ) }
      </div>
    );
  }

  render( ) {
    const { garmin, closeGarminImport, disconnectGarmin } = this.props;
    if ( !garmin || !garmin.enabled ) return null;
    return (
      <Modal
        show={garmin.show}
        onHide={closeGarminImport}
        className="GarminImportModal"
      >
        <Modal.Header closeButton>
          <Modal.Title>{ I18n.t( "gps_track_garmin_title" ) }</Modal.Title>
        </Modal.Header>
        <Modal.Body>
          { garmin.error && <div className="alert alert-danger">{ garmin.error }</div> }
          { garmin.token ? this.renderActivities( ) : this.renderKeyForm( ) }
        </Modal.Body>
        <Modal.Footer>
          { garmin.token && (
            <Button bsStyle="link" className="pull-left" onClick={disconnectGarmin}>
              { I18n.t( "disconnect" ) }
            </Button>
          ) }
          <Button onClick={closeGarminImport}>{ I18n.t( "close" ) }</Button>
        </Modal.Footer>
      </Modal>
    );
  }
}

GarminImportModal.propTypes = {
  garmin: PropTypes.object,
  obsCards: PropTypes.object,
  files: PropTypes.object,
  closeGarminImport: PropTypes.func,
  connectGarmin: PropTypes.func,
  disconnectGarmin: PropTypes.func,
  importGarminActivity: PropTypes.func,
  loadGarminActivities: PropTypes.func
};

GarminImportModal.defaultProps = {
  obsCards: {},
  files: {}
};

export default GarminImportModal;
