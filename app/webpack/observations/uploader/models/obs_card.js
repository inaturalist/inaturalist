import _ from "lodash";
import inatjs from "inaturalistjs";
import actions from "../actions/actions";

const ObsCard = class ObsCard {
  constructor( attrs ) {
    const defaultAttrs = {
      id: new Date( ).getTime( ),
      files: { },
      date: null,
      taxon_id: null,
      save_state: "pending",
      bounds: null,
      zoom: null
    };
    Object.assign( this, defaultAttrs, attrs );
  }

  blank( ) {
    return (
      _.isEmpty( this.files ) &&
      !this.description &&
      !this.date &&
      !this.taxon_id &&
      !this.latitude
    );
  }

  upload( file, dispatch ) {
    if ( !this.files[file.id] ) { return; }
    dispatch( actions.updateObsCardFile( this, file, { upload_state: "uploading" } ) );
    inatjs.photos.create( { file: file.file }, { same_origin: true } ).then( r => {
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
        positional_accuracy: this.accuracy
      }
    };
    if ( this.taxon_id ) { params.observation.taxon_id = this.taxon_id; }
    if ( this.date ) { params.observation.observed_on_string = this.date; }
    const photoIDs = _.compact( _.map( this.files, f => ( f.photo.id ) ) );
    if ( photoIDs.length > 0 ) { params.local_photos = { 0: photoIDs }; }
    inatjs.observations.create( params, { same_origin: true } ).then( ( ) => {
      dispatch( actions.updateObsCard( this, { save_state: "saved" } ) );
    } ).catch( e => {
      console.log( "Save failed:", e );
      dispatch( actions.updateObsCard( this, { save_state: "failed" } ) );
    } );
  }
};

export default ObsCard;
