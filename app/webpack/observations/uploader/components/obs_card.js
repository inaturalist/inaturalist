import inatjs from "inaturalistjs";
import * as actions from "../actions/actions";

const ObsCard = class ObsCard {
  constructor( attrs ) {
    Object.assign( this, attrs );
  }

  upload( ) {
    this.dispatch( actions.updateFile( this, { description: "uploading" } ) );
    inatjs.photos.create({ file: this.file }).then( r => {
      this.dispatch( actions.updateFile( this, { description: "uploaded" } ) );
    }).catch( e => {
      this.dispatch( actions.updateFile( this, { description: "failed" } ) );
    });
  }
};

export default ObsCard;
