import _ from "lodash";
import inaturalistjs from "inaturalistjs";
import actions from "../actions/actions";
import moment from "moment-timezone";

const ObsCard = class ObsCard {
  constructor( attrs ) {
    const defaultAttrs = {
      id: new Date( ).getTime( ),
      save_state: "pending",
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
      /* global TIMEZONE */
      time_zone: TIMEZONE
    };
    Object.assign( this, defaultAttrs, attrs );
  }

  blank( ) {
    return (
      _.isEmpty( this.files ) &&
      !this.description &&
      !this.date &&
      !this.taxon_id &&
      !this.latitude &&
      !this.species_guess
    );
  }

  nonUploadedFiles( ) {
    return _.filter( this.files, f =>
      f.upload_state === "uploading" || f.upload_state === "pending" );
  }

  uploadedFiles( ) {
    return _.filter( this.files, f => f.upload_state === "uploaded" );
  }

  uploadedFileIDs( ) {
    return _.map( this.uploadedFiles( ), f => f.id );
  }

  momentDate( ) {
    let m;
    if ( this.date &&
         this.date.match( /\d{2}\/\d{2}\/\d{2}(\d{2})? \d{1,2}:\d{2} [AP]M [-+]\d{1,2}:\d{2}/ ) ) {
      const d = new Date( this.date );
      m = d && moment( d );
      if ( m && m.isValid( ) ) {
        return m;
      }
    }
    return undefined;
  }

  additionalPhotoMetadata( files ) {
    const updates = { };
    _.each( files || this.files, f => {
      Object.assign( updates, f.additionalPhotoMetadata( Object.assign( { }, this, updates ) ) );
    } );
    return updates;
  }

  upload( file, dispatch ) {
    if ( !this.files[file.id] ) { return; }
    dispatch( actions.updateObsCardFile( this, file, { upload_state: "uploading" } ) );
    inaturalistjs.photos.create( { file: file.file }, { same_origin: true } ).then( r => {
      const updates = this.additionalPhotoMetadata( );
      if ( !_.isEmpty( updates ) ) {
        dispatch( actions.updateObsCard( this, Object.assign( updates, { modified: false } ) ) );
      }
      dispatch( actions.updateObsCardFile( this, file, { upload_state: "uploaded", photo: r } ) );
    } ).catch( e => {
      console.log( "Upload failed:", e );
      dispatch( actions.updateObsCardFile( this, file, { upload_state: "failed" } ) );
    } );
  }

  save( dispatch ) {
    if ( this.blank( ) ) {
      dispatch( actions.updateObsCard( this, { save_state: "saved" } ) );
      return;
    }
    if ( this.save_state !== "pending" ) { return; }
    dispatch( actions.updateObsCard( this, { save_state: "saving" } ) );
    const params = {
      observation: {
        description: this.description,
        latitude: this.latitude,
        longitude: this.longitude,
        positional_accuracy: this.accuracy,
        geoprivacy: this.geoprivacy,
        place_guess: this.locality_notes,
        observation_field_values_attributes: this.observation_field_values,
        tag_list: this.tags.join( "," ),
        captive_flag: this.captive
      }
    };
    if ( this.taxon_id ) { params.observation.taxon_id = this.taxon_id; }
    if ( this.species_guess ) { params.observation.species_guess = this.species_guess; }
    if ( this.date ) { params.observation.observed_on_string = this.date; }
    const photoIDs = _.compact( _.map( this.files, f => ( f.photo.id ) ) );
    if ( photoIDs.length > 0 ) { params.local_photos = { 0: photoIDs }; }
    inaturalistjs.observations.create( params, { same_origin: true } ).then( ( ) => {
      dispatch( actions.updateObsCard( this, { save_state: "saved" } ) );
    } ).catch( e => {
      console.log( "Save failed:", e );
      dispatch( actions.updateObsCard( this, { save_state: "failed" } ) );
    } );
  }
};

export default ObsCard;
