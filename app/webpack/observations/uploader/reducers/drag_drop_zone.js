import * as types from "../constants/constants";
import update from "react-addons-update";

const dragDropZone = ( state = { files: {} }, action ) => {
  switch ( action.type ) {
    case types.UPLOAD_FILES: {
      return update( state, {
        files: { $merge: action.files }
      } );
    }
    case types.UPDATE_FILE: {
      return update( state, {
        files: { [action.file.id]: { $merge: action.attrs } }
      } );
    }
    default:
      return state;
  }
};

export default dragDropZone;
