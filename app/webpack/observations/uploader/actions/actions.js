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

  static updateObsCard( obsCard, attrs ) {
    return function ( dispatch ) {
      dispatch( { type: types.UPDATE_OBS_CARD, obsCard, attrs } );
      // any time a card's upload_state changes, see
      // if there are other images that could be uploaded
      if ( attrs.upload_state ) {
        dispatch( actions.uploadImages( ) );
      }
    };
  }

  static submitObservations( ) {
    return function ( dispatch, getState ) {
      const s = getState( );
      dispatch( { type: types.SUBMIT_OBSERVATIONS } );
      for ( const id in s.dragDropZone.obsCards ) {
        if ( s.dragDropZone.obsCards[id] ) {
          const c = s.dragDropZone.obsCards[id];
          const params = {
            observation: {
              description: c.description || ''
            }
          };
          if ( c.taxon_id ) { params.observation.taxon_id = c.taxon_id; }
          if ( c.photo ) {
            params.local_photos = { 0: [c.photo.id] };
          }
          inatjs.observations.create( params );
        }
      }
    };
  }

  static uploadImages( ) {
    return function ( dispatch, getState ) {
      const s = getState( );
      const stateCounts = { pending: 0, uploading: 0, uploaded: 0, failed: 0 };
      let nextToUpload;
      for ( const id in s.dragDropZone.obsCards ) {
        if ( s.dragDropZone.obsCards[id] ) {
          const c = s.dragDropZone.obsCards[id];
          stateCounts[c.upload_state] = stateCounts[c.upload_state] || 0;
          stateCounts[c.upload_state] += 1;
          if ( c.upload_state === "pending" && !nextToUpload ) {
            nextToUpload = c;
          }
        }
      }
      if ( nextToUpload && stateCounts.uploading < s.dragDropZone.maximumNumberOfUploads ) {
        nextToUpload.upload( );
      } else if ( nextToUpload ) {
        // console.log( "waiting for existing uploads to finish" );
      }
    };
  }
};


export default actions;
