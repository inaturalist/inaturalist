import inatjs from "inaturalistjs";
import actions from "../actions/actions";

const ObsCard = class ObsCard {
  constructor( attrs ) {
    Object.assign( this, attrs );
  }

  upload( ) {
    this.dispatch( actions.updateObsCard( this, {
      description: "uploading", upload_state: "uploading" } ) );
    inatjs.photos.create( { file: this.file }, { same_origin: true } ).then( r => {
      this.dispatch( actions.updateObsCard( this, {
        description: "uploaded", upload_state: "uploaded", photo: r } ) );
    } ).catch( e => {
      console.log( "Upload failed:", e );
      this.dispatch( actions.updateObsCard( this, {
        description: "failed", upload_state: "failed" } ) );
    } );
  }
};

export default ObsCard;
