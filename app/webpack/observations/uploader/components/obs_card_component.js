import React, { Component } from "react";
import PropTypes from "prop-types";
import { DragSource, DropTarget } from "react-dnd";
import { Glyphicon, OverlayTrigger, Tooltip } from "react-bootstrap";
import { pipe } from "ramda";
import Dropzone from "react-dropzone";
import _ from "lodash";
import moment from "moment-timezone";
import TaxonAutocomplete from "./taxon_autocomplete";
import DateTimeFieldWrapper from "./date_time_field_wrapper";
import FileGallery from "./file_gallery";
import util, { ACCEPTED_FILE_TYPES, DATETIME_WITH_TIMEZONE, DATETIME_WITH_TIMEZONE_OFFSET } from "../models/util";

const cardSource = {
  canDrag( props ) {
    if (
      $( `div[data-id=${props.obsCard.id}] input:focus` ).length > 0
      || $( `div[data-id=${props.obsCard.id}] textarea:focus` ).length > 0
      || $( ".bootstrap-datetimepicker-widget:visible" ).length > 0
    ) {
      return false;
    }
    return true;
  },
  beginDrag( props, monitor, component ) {
    component.closeDatepicker( );
    props.setState( { draggingProps: props } );
    return props;
  },
  endDrag( props ) {
    props.setState( { draggingProps: null } );
    return props;
  }
};

const cardTarget = {
  canDrop( props, monitor ) {
    const item = monitor.getItem( );
    return item.obsCard.id !== props.obsCard.id;
  },
  drop( props, monitor, component ) {
    if ( monitor.didDrop( ) ) { return; }
    const item = monitor.getItem( );
    const dropResult = component.props;
    if ( dropResult && item.obsCard.id !== props.obsCard.id ) {
      props.mergeObsCards( _.fromPairs(
        _.map( [item.obsCard, dropResult.obsCard], c => [c.id, c] )
      ), dropResult.obsCard );
    }
  }
};

const fileTarget = {
  // don't define canDrop. When a photo is dropped on its own card
  // the action is caught below in drop, and will not fire on drop
  // in the containing div, preventing a new card from being created
  drop( props, monitor, component ) {
    if ( monitor.didDrop( ) ) { return; }
    const item = monitor.getItem( );
    const dropResult = component.props;
    if ( dropResult && item.obsCard.id !== props.obsCard.id ) {
      props.movePhoto( item, dropResult.obsCard );
    }
  }
};

class ObsCardComponent extends Component {
  static collectCard( connect, monitor ) {
    return {
      cardDragSource: connect.dragSource( ),
      cardIsDragging: monitor.isDragging( )
    };
  }

  static collectCardDrop( connect, monitor ) {
    return {
      cardDropTarget: connect.dropTarget( ),
      cardIsOver: monitor.isOver( )
    };
  }

  static collectFileDrop( connect, monitor ) {
    return {
      fileDropTarget: connect.dropTarget( ),
      fileIsOver: monitor.isOver( )
    };
  }

  constructor( props, context ) {
    super( props, context );
    this.openLocationChooser = this.openLocationChooser.bind( this );
    this.closeDatepicker = this.closeDatepicker.bind( this );
    this.onDragEnter = this.onDragEnter.bind( this );
  }

  shouldComponentUpdate( nextProps ) {
    const {
      fileIsOver,
      cardIsDragging,
      cardIsOver,
      obsCard,
      selectedSpeciesGuess
    } = this.props;
    const b = (
      fileIsOver !== nextProps.fileIsOver
      || cardIsDragging !== nextProps.cardIsDragging
      || cardIsOver !== nextProps.cardIsOver
      || obsCard.galleryIndex !== nextProps.obsCard.galleryIndex
      || selectedSpeciesGuess !== nextProps.selectedSpeciesGuess
      || obsCard.saveState !== nextProps.obsCard.saveState
      || _.size( obsCard.files ) !== _.size( nextProps.obsCard.files )
      || !_.isMatch( obsCard, nextProps.obsCard )
    );
    return b;
  }

  onDragEnter( ) {
    const pickerState = this.refs.datetime.pickerState( );
    // if the datepicker is open
    if ( pickerState && pickerState.showPicker ) {
      // close it
      this.refs.datetime.close( );
      // and send this card's dropzone a fake drop event to reset it
      this.refs.dropzone.onDrop( {
        dataTransfer: { files: [] },
        preventDefault: () => { }
      } );
    }
  }

  openLocationChooser( ) {
    const { setState, obsCard } = this.props;
    setState( {
      locationChooser: {
        show: true,
        lat: obsCard.latitude,
        lng: obsCard.longitude,
        radius: obsCard.accuracy,
        geoprivacy: obsCard.geoprivacy,
        obsCard,
        zoom: obsCard.zoom,
        center: obsCard.center,
        bounds: obsCard.bounds,
        notes: obsCard.locality_notes,
        manualPlaceGuess: obsCard.manualPlaceGuess
      }
    } );
  }

  closeDatepicker( ) {
    if ( this.refs.datetime ) {
      this.refs.datetime.close( );
    }
  }

  render( ) {
    const {
      cardDragSource,
      cardDropTarget,
      cardIsDragging,
      cardIsOver,
      confirmRemoveFile,
      confirmRemoveObsCard,
      draggingProps,
      fileDropTarget,
      fileIsOver,
      obsCard,
      onCardDrop,
      selectCard,
      setState,
      updateObsCard,
      config
    } = this.props;
    let className = "cellDropzone thumbnail card ui-selectee";
    if ( cardIsDragging ) { className += " dragging"; }
    if ( cardIsOver || fileIsOver ) { className += " dragOver"; }
    if ( obsCard.selected ) { className += " selected ui-selecting"; }
    if ( obsCard.saveState === "saving" ) { className += " saving"; }
    if ( obsCard.saveState === "saved" ) { className += " saved"; }
    if ( obsCard.saveState === "failed" ) { className += " failed"; }
    const locationText = obsCard.locality_notes || (
      obsCard.latitude
      && `${_.round( obsCard.latitude, 4 )},${_.round( obsCard.longitude, 4 )}`
    );
    let captiveMarker;
    if ( obsCard.captive ) {
      captiveMarker = (
        <button
          type="button"
          className="label-captive"
          title={I18n.t( "captive_cultivated" )}
          alt={I18n.t( "captive_cultivated" )}
        >
          C
        </button>
      );
    }
    let photoCountOrStatus;
    const fileCount = _.size( obsCard.files );
    if ( fileCount ) {
      if (
        _.find( obsCard.files, f => f.uploadState === "uploading" || f.uploadState === "pending" )
      ) {
        photoCountOrStatus = I18n.t( "loading_metadata" );
      } else if ( fileCount > 1 ) {
        photoCountOrStatus = `${obsCard.galleryIndex || 1}/${fileCount}`;
      }
    }
    const invalidDate = util.dateInvalid( obsCard.date );

    let locationIcon = <Glyphicon glyph="map-marker" />;
    if ( obsCard.geoprivacy === "obscured" ) {
      locationIcon = <i className="icon-icn-location-obscured" />;
    } else if ( obsCard.geoprivacy === "private" ) {
      locationIcon = <i className="icon-icn-location-private" />;
    }

    let inputFormat = DATETIME_WITH_TIMEZONE;
    if ( obsCard.time_zone ) {
      if (
        parseInt( moment().tz( obsCard.time_zone ).format( "z" ), 0 )
        && parseInt( moment().tz( obsCard.time_zone ).format( "z" ), 0 ) !== 0
      ) {
        inputFormat = DATETIME_WITH_TIMEZONE_OFFSET;
      }
    }

    return cardDropTarget( fileDropTarget( cardDragSource(
      <div
        className="ObsCardComponent"
        onClick={() => selectCard( obsCard )}
        draggable
      >
        <Dropzone
          ref="dropzone"
          className={className}
          data-id={obsCard.id}
          disableClick
          onDrop={f => onCardDrop( f, obsCard )}
          onDragEnter={this.onDragEnter}
          activeClassName="hover"
          accept={ACCEPTED_FILE_TYPES}
          key={obsCard.id}
        >
          { captiveMarker }
          <OverlayTrigger
            placement="top"
            delayShow={1000}
            overlay={(
              <Tooltip id="remove-obs-tip">
                { I18n.t( "uploader.tooltips.remove_observation" ) }
              </Tooltip>
            )}
          >
            <button
              type="button"
              className="btn-close"
              onClick={confirmRemoveObsCard}
            >
              <Glyphicon glyph="remove" />
            </button>
          </OverlayTrigger>
          <FileGallery
            obsCard={obsCard}
            setState={setState}
            draggingProps={draggingProps}
            updateObsCard={updateObsCard}
            confirmRemoveFile={confirmRemoveFile}
          />
          <div className="caption">
            <p className="photo-count">
              { photoCountOrStatus || "\u00a0" }
            </p>
            <TaxonAutocomplete
              key={
                `taxonac${obsCard.selected_taxon && obsCard.selected_taxon.title}`
              }
              small
              bootstrap
              searchExternal
              showPlaceholder
              perPage={6}
              visionParams={obsCard.visionParams( )}
              initialSelection={obsCard.selected_taxon}
              initialTaxonID={obsCard.taxon_id}
              resetOnChange={false}
              afterSelect={r => {
                if ( !obsCard.selected_taxon || r.item.id !== obsCard.selected_taxon.id ) {
                  updateObsCard( obsCard, {
                    taxon_id: r.item.id,
                    selected_taxon: r.item,
                    species_guess: r.item.title,
                    modified: r.item.id !== obsCard.taxon_id
                  } );
                }
              }}
              afterUnselect={( ) => {
                if ( obsCard.selected_taxon ) {
                  updateObsCard( obsCard, {
                    taxon_id: null,
                    selected_taxon: null,
                    species_guess: null
                  } );
                }
              }}
              config={config}
            />
            <DateTimeFieldWrapper
              key={`datetime${obsCard.selected_date}`}
              reactKey={`datetime${obsCard.selected_date}`}
              ref="datetime"
              inputFormat={inputFormat}
              dateTime={obsCard.selected_date
                ? moment( obsCard.selected_date, inputFormat ).format( "x" )
                : undefined
              }
              timeZone={obsCard.time_zone}
              onChange={dateString => updateObsCard( obsCard, { date: dateString } )}
              onSelection={
                dateString => updateObsCard(
                  obsCard, { date: dateString, selected_date: dateString }
                )
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
                placeholder={I18n.t( "date_" )}
              />
            </div>
            <div
              className="input-group"
              onClick={this.openLocationChooser}
            >
              <div className="input-group-addon input-sm">
                { locationIcon }
              </div>
              <input
                type="text"
                className="form-control input-sm"
                value={locationText || ""}
                placeholder={I18n.t( "location" )}
                readOnly
              />
            </div>
            <div className="form-group">
              <textarea
                placeholder={
                  I18n.t( "notes", {
                    defaultValue: I18n.t( "activerecord.attributes.observation.description" )
                  } )
                }
                className="form-control input-sm"
                value={obsCard.description || ""}
                onChange={e => updateObsCard( obsCard, { description: e.target.value } )}
              />
            </div>
          </div>
        </Dropzone>
      </div>
    ) ) );
  }
}

ObsCardComponent.propTypes = {
  cardDragSource: PropTypes.func,
  cardDropTarget: PropTypes.func,
  cardIsDragging: PropTypes.bool,
  cardIsOver: PropTypes.bool,
  confirmRemoveFile: PropTypes.func,
  confirmRemoveObsCard: PropTypes.func,
  draggingProps: PropTypes.object,
  files: PropTypes.object,
  obsCard: PropTypes.object,
  onCardDrop: PropTypes.func,
  fileDropTarget: PropTypes.func,
  fileIsOver: PropTypes.bool,
  selectCard: PropTypes.func,
  selectedSpeciesGuess: PropTypes.string,
  setState: PropTypes.func,
  updateObsCard: PropTypes.func,
  config: PropTypes.object
};

export default pipe(
  DragSource( "ObsCard", cardSource, ObsCardComponent.collectCard ),
  DropTarget( "ObsCard", cardTarget, ObsCardComponent.collectCardDrop ),
  DropTarget( ["Photo", "Sound"], fileTarget, ObsCardComponent.collectFileDrop )
)( ObsCardComponent );
