import _ from "lodash";
import inaturalistjs from "inaturalistjs";
import moment from "moment";
import { v4 as uuidv4 } from "uuid";
import actions from "../actions/actions";
import util from "./util";

const ObsCard = class ObsCard {
  constructor( attrs ) {
    const defaultAttrs = {
      id: new Date( ).getTime( ),
      saveState: "pending",
      geoprivacy: "open",
      files: { },
      date: null,
      taxon_id: null,
      bounds: null,
      zoom: null,
      latitude: null,
      longitude: null,
      accuracy: null,
      species_guess: null,
      tags: [],
      observation_field_values: [],
      projects: [],
      changedFields: { },
      validationErrors: { },
      uuid: uuidv4()
    };
    Object.assign( this, defaultAttrs, attrs );
  }

  blank( ) {
    return (
      _.isEmpty( this.files )
      && _.isEmpty( this.tags )
      && _.isEmpty( this.observation_field_values )
      && _.isEmpty( this.projects )
      && !this.description
      && !this.date
      && !this.taxon_id
      && !this.latitude
      && !this.species_guess
    );
  }

  nonUploadedFiles( ) {
    return _.filter(
      this.files,
      f => f.uploadState === "uploading" || f.uploadState === "pending"
    );
  }

  uploadedFiles( ) {
    return _.filter( this.files, f => f.uploadState === "uploaded" );
  }

  uploadedFileIDs( ) {
    return _.map( _.sortBy( this.uploadedFiles( ), "sort" ), f => f.id );
  }

  momentDate( ) {
    let m;
    if (
      this.date
      && this.date.match( /\d{2}\/\d{2}\/\d{2}(\d{2})? \d{1,2}:\d{2} [AP]M [-+]\d{1,2}:\d{2}/ )
    ) {
      const d = new Date( this.date );
      m = d && moment( d );
      if ( m && m.isValid( ) ) {
        return m;
      }
    }
    return null;
  }

  visionParams( ) {
    const firstThumbnail = _.first(
      _.compact(
        _.map( _.sortBy( this.files, "sort" ), f => f.visionThumbnail )
      )
    );
    if ( !firstThumbnail ) { return null; }
    const params = { image: firstThumbnail };
    if ( this.latitude ) { params.lat = this.latitude; }
    if ( this.longitude ) { params.lng = this.longitude; }
    if ( this.date ) { params.observed_on = this.date; }
    return params;
  }

  // usually called when a card acquires a new photo, this will return
  // all fields with metadata attached to the photo, where the corresponding
  // field on the card is currently blank
  newMetadataFromFile( file ) {
    const newMetadata = { };
    const fileMetadata = { ...file.metadata, ...file.serverMetadata };
    _.each( fileMetadata, ( v, k ) => {
      if (
        _.isEmpty( this[k] )
        && !_.isBoolean( this[k] )
        && !_.isNumber( this[k] )
        && !_.has( this.changedFields, k )
      ) {
        newMetadata[k] = v;
      }
    } );
    return newMetadata;
  }

  save( options = { } ) {
    return dispatch => {
      if ( this.blank( ) ) {
        dispatch( actions.updateObsCard( this, { saveState: "saved" } ) );
        return;
      }
      if ( this.saveState !== "pending" ) { return; }
      dispatch( actions.updateObsCard( this, { saveState: "saving" } ) );
      const params = {
        observation: {
          description: this.description,
          latitude: this.latitude,
          longitude: this.longitude,
          positional_accuracy: this.accuracy,
          geoprivacy: this.geoprivacy,
          place_guess: this.locality_notes,
          observation_field_values_attributes: ( this.observation_field_values || [] ).map(
            ofv => _.pick( ofv, ["value", "observation_field_id"] )
          ),
          tag_list: this.tags.join( "," ),
          captive_flag: this.captive,
          uuid: this.uuid
        },
        project_id: _.map( this.projects, "id" ),
        uploader: true
      };
      if ( options.refresh ) {
        params.force_refresh = true;
      } else {
        params.skip_refresh = true;
      }
      if ( this.taxon_id ) { params.observation.taxon_id = this.taxon_id; }
      if ( this.species_guess ) { params.observation.species_guess = this.species_guess; }
      if ( this.date && !util.dateInvalid( this.date ) ) {
        params.observation.observed_on_string = this.date;
      }
      if ( this.selected_taxon && this.selected_taxon.isVisionResult ) {
        params.observation.owners_identification_from_vision_requested = true;
      }
      const photoIDs = _.compact( _.map( _.sortBy( this.files, "sort" ), f => (
        f.photo ? f.photo.id : null ) ) );
      if ( photoIDs.length > 0 ) { params.local_photos = { 0: photoIDs }; }
      const soundIDs = _.compact( _.map( _.sortBy( this.files, "sort" ), f => (
        f.sound ? f.sound.id : null ) ) );
      if ( soundIDs.length > 0 ) { params.local_sounds = { 0: soundIDs }; }

      inaturalistjs.observations.create( params, { same_origin: true } ).then( r => {
        dispatch( actions.updateObsCard( this, {
          saveState: "saved",
          serverResponse: r && r[0]
        } ) );
      } ).catch( e => {
        dispatch( actions.handleUploadFailure(
          e,
          this,
          ( ) => this.save( dispatch ),
          ( ) => {
            let errors = [I18n.t( "unknown_error" )];
            if ( !e.response ) {
              dispatch( actions.updateObsCard( this, { saveState: "failed", saveErrors: errors } ) );
              return;
            }
            e.response.json( )
              .then( errorJSON => {
                if ( errorJSON && errorJSON.errors && errorJSON.errors[0] ) {
                  errors = errorJSON.errors[0];
                }
              } )
              .catch( ( ) => {
                // This will happen if for some reason we get an error that doesn't
                // have a parsable JSON response body, e.g. something unexpected above
                // the application, e.g. in Varnish
                errors = [I18n.t( "unknown_error" )];
              } )
              .finally( ( ) => {
                dispatch( actions.updateObsCard( this, { saveState: "failed", saveErrors: errors } ) );
              } );
          }
        ) );
      } );
    };
  }

  validate( ) {
    this.validationErrors = { };
    if ( _.size( this.files ) === 0 ) {
      this.validationErrors.media = true;
    }
    if ( !this.taxon_id && !this.species_guess ) {
      this.validationErrors.taxon = true;
    }
    if ( !this.date ) {
      this.validationErrors.date = true;
    }
    if ( ( !this.latitude || !this.longitude ) ) {
      this.validationErrors.location = true;
    }
  }
};

export default ObsCard;
