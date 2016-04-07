import * as types from "../constants/constants";
import inatjs from "inaturalistjs";

const actions = class actions {
  static drag( draggedCol, targetCol ) {
    return { type: types.DRAG, draggedCol, targetCol };
  }

  static appendObsCards( obsCards ) {
    return { type: types.APPEND_OBS_CARDS, obsCards };
  }

  static selectObsCards( ids ) {
    return { type: types.SELECT_OBS_CARDS, ids };
  }

  static createBlankObsCard( obsCards ) {
    return { type: types.CREATE_BLANK_OBS_CARD, obsCards };
  }

  static removeObsCard( obsCard ) {
    return { type: types.REMOVE_OBS_CARD, obsCard };
  }

  static updateSelectedObsCards( attrs ) {
    return { type: types.UPDATE_SELECTED_OBS_CARDS, attrs };
  }

  static submitObservations( ) {
    return function ( dispatch, getState ) {
      const s = getState( );
      dispatch( { type: types.SUBMIT_OBSERVATIONS } );
      for ( const id in s.dragDropZone.obsCards ) {
        const c = s.dragDropZone.obsCards[id];
        inatjs.observations.create( {
          observation: {
            description: c.name
          },
          local_photos: {
            0: [ c.photo.id ]
          }
        } );
      }
    };
  }

  static updateObsCard( obsCard, attrs ) {
    return function ( dispatch ) {
      dispatch( { type: types.UPDATE_OBS_CARD, obsCard, attrs } );
      if ( attrs.upload_state ) {
        dispatch( actions.uploadImages( ) );
      }
    };
  }

  static uploadImages( ) {
    return function ( dispatch, getState ) {
      const s = getState( );
      var stateCounts = { pending: 0, uploading: 0, uploaded: 0, failed: 0 };
      var nextToUpload;
      for ( const id in s.dragDropZone.obsCards ) {
        const c = s.dragDropZone.obsCards[id];
        stateCounts[c.upload_state] = stateCounts[c.upload_state] || 0;
        stateCounts[c.upload_state] += 1;
        if ( c.upload_state === "pending" && !nextToUpload ) {
          nextToUpload = c;
        }
      }
      // console.log(stateCounts);
      // console.log(stateCounts);
      // console.log(nextToUpload);
      if ( nextToUpload && stateCounts.uploading < s.dragDropZone.maximumNumberOfUploads ) {
        // console.log( "found one to upload" );
        nextToUpload.upload( );
      } else if ( nextToUpload ) {
        // console.log( "waiting" );
      }
    };
  }
};


export default actions;
