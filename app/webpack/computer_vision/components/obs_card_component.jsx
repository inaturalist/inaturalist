import React, { Component } from "react";
import PropTypes from "prop-types";
import { Glyphicon, OverlayTrigger, Tooltip } from "react-bootstrap";
import _ from "lodash";
import moment from "moment-timezone";
import TaxonAutocomplete from "../../observations/uploader/components/taxon_autocomplete";
import DateTimeFieldWrapper from "../../observations/uploader/components/date_time_field_wrapper";
import util from "../../observations/uploader/models/util";

class ObsCardComponent extends Component {
  constructor( props, context ) {
    super( props, context );
    this.openLocationChooser = this.openLocationChooser.bind( this );
  }

  openLocationChooser( ) {
    const { setLocationChooser, obsCard } = this.props;
    setLocationChooser( {
      show: true,
      lat: obsCard.latitude,
      lng: obsCard.longitude,
      radius: obsCard.accuracy,
      obsCard,
      zoom: obsCard.zoom,
      center: obsCard.center,
      bounds: obsCard.bounds,
      notes: obsCard.locality_notes,
      manualPlaceGuess: obsCard.manualPlaceGuess
    } );
  }

  render( ) {
    const { obsCard, updateObsCard } = this.props;
    let photo;
    if (
      !( obsCard.uploadedFile.uploadState === "failed" )
      && (
        ( obsCard.uploadedFile.preview && !obsCard.uploadedFile.photo )
        || ( obsCard.uploadedFile.photo && obsCard.uploadedFile.uploadState !== "failed" )
      )
    ) {
      // preview photo
      photo = (
        <div className="photoDrag">
          <img
            className="img-thumbnail"
            src={obsCard.uploadedFile.preview}
            alt={obsCard.uploadedFile.name}
          />
        </div>
      );
    } else {
      photo = (
        <div className="failed">
          <OverlayTrigger
            placement="top"
            delayShow={1000}
            overlay={(
              <Tooltip id="merge-tip">{ I18n.t( "uploader.tooltips.photo_failed" ) }</Tooltip>
            )}
          >
            <Glyphicon glyph="exclamation-sign" />
          </OverlayTrigger>
        </div>
      );
    }

    const loadingText = (
      obsCard.uploadedFile.uploadState === "uploading"
      || obsCard.uploadedFile.uploadState === "pending"
    )
      ? I18n.t( "loading_metadata" )
      : "\u00a0";
    const invalidDate = util.dateInvalid( obsCard.date );
    const locationText = obsCard.locality_notes
      || (
        obsCard.latitude
        && `${_.round( obsCard.latitude, 4 )},${_.round( obsCard.longitude, 4 )}`
      );
    return (
      <div className={`uploadedPhoto thumbnail ${obsCard.visionResults ? "completed" : ""}`}>
        <div className="img-container">
          { photo }
        </div>
        <div className="caption">
          <p className="photo-count">
            { loadingText }
          </p>
          <TaxonAutocomplete
            small
            bootstrap
            searchExternal
            showPlaceholder
            perPage={6}
            resetOnChange={false}
            afterSelect={r => {
              if ( !obsCard.selected_taxon || r.item.id !== obsCard.selected_taxon.id ) {
                updateObsCard( {
                  taxon_id: r.item.id,
                  selected_taxon: r.item,
                  species_guess: r.item.title
                } );
              }
            }}
            afterUnselect={( ) => {
              if ( obsCard.selected_taxon ) {
                updateObsCard( {
                  taxon_id: null,
                  selected_taxon: null,
                  species_guess: null
                } );
              }
            }}
          />
          <DateTimeFieldWrapper
            ref="datetime"
            inputFormat="YYYY/MM/DD"
            mode="date"
            dateTime={
              obsCard.selected_date
                ? moment( obsCard.selected_date, "YYYY/MM/DD" ).format( "x" )
                : undefined
            }
            timeZone={obsCard.time_zone}
            onChange={dateString => updateObsCard( { date: dateString } )}
            onSelection={
              dateString => updateObsCard( { date: dateString, selected_date: dateString } )
            }
          />
          <div
            className={`input-group${invalidDate ? " has-error" : ""}`}
            onClick={() => {
              if ( this.refs.datetime ) {
                this.refs.datetime.onClick( );
              }
            }}
          >
            <div className="input-group-addon input-sm">
              <Glyphicon glyph="calendar" />
            </div>
            <input
              type="text"
              className="form-control input-sm"
              value={obsCard.date || ""}
              onChange={e => {
                if ( this.refs.datetime ) {
                  this.refs.datetime.onChange( undefined, e.target.value );
                }
              }}
              placeholder={this.refs.datetime ? "" : I18n.t( "date_" )}
            />
          </div>
          <div
            className="input-group"
            onClick={this.openLocationChooser}
          >
            <div className="input-group-addon input-sm">
              <Glyphicon glyph="map-marker" />
            </div>
            <input
              type="text"
              className="form-control input-sm"
              value={locationText || ""}
              placeholder={locationText ? "" : I18n.t( "location" )}
              readOnly
            />
          </div>
        </div>
      </div>
    );
  }
}

ObsCardComponent.propTypes = {
  obsCard: PropTypes.object,
  updateObsCard: PropTypes.func,
  setLocationChooser: PropTypes.func
};

export default ObsCardComponent;
