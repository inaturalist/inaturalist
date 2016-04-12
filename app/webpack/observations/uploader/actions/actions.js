import * as types from "../constants/constants";
import DroppedFile from "../models/dropped_file";
import ObsCard from "../models/obs_card";
import _ from "lodash";

const actions = class actions {

  static setState( attrs ) {
    return { type: types.SET_STATE, attrs };
  }

  static updateState( attrs ) {
    return { type: types.UPDATE_STATE, attrs };
  }

  static drag( draggedCol, targetCol ) {
    return { type: types.DRAG, draggedCol, targetCol };
  }

  static appendObsCards( obsCards ) {
    return { type: types.APPEND_OBS_CARDS, obsCards };
  }

  static selectObsCards( ids ) {
    return { type: types.SELECT_OBS_CARDS, ids };
  }

  static removeObsCard( obsCard ) {
    return { type: types.REMOVE_OBS_CARD, obsCard };
  }

  static updateSelectedObsCards( attrs ) {
    return { type: types.UPDATE_SELECTED_OBS_CARDS, attrs };
  }

  static confirmRemoveSelected( ) {
    return function ( dispatch, getState ) {
      const s = getState( );
      dispatch( actions.setState( { removeModal: {
        show: true,
        count: _.keys( s.dragDropZone.selectedObsCards ).length
      } } ) );
    };
  }

  static confirmRemoveObsCard( obsCard ) {
    return function ( dispatch ) {
      dispatch( actions.setState( { removeModal: {
        show: true,
        count: 1,
        obsCard
      } } ) );
    };
  }

  static removeSelected( ) {
    return { type: types.REMOVE_SELECTED };
  }

  static selectAll( ) {
    return { type: types.SELECT_ALL };
  }

  static createBlankObsCard( ) {
    return function ( dispatch ) {
      const obsCard = new ObsCard( );
      dispatch( { type: types.CREATE_BLANK_OBS_CARD, obsCard } );
    };
  }

  static updateObsCard( obsCard, attrs ) {
    return function ( dispatch ) {
      dispatch( { type: types.UPDATE_OBS_CARD, obsCard, attrs } );
      if ( attrs.save_state ) {
        dispatch( actions.saveObservations( ) );
      }
    };
  }

  static mergeObsCards( fromObsCard, toObsCard ) {
    return function ( dispatch ) {
      const mergedFiles = Object.assign( { }, toObsCard.files );

      let i = 0;
      const startTime = new Date( ).getTime( );
      _.each( fromObsCard.files, f => {
        const id = ( startTime + i );
        mergedFiles[id] = new DroppedFile( Object.assign( { }, f, { id: id } ) );
        i += 1;
      } );

      dispatch( { type: types.UPDATE_OBS_CARD, obsCard: toObsCard, attrs: {
        files: mergedFiles
      } } );
      dispatch( { type: types.REMOVE_OBS_CARD, obsCard: fromObsCard } );
    };
  }

  static updateObsCardFile( obsCard, file, attrs ) {
    return function ( dispatch ) {
      dispatch( { type: types.UPDATE_OBS_CARD_FILE, obsCard, file, attrs } );
      dispatch( actions.uploadImages( ) );
    };
  }

  static submitObservations( ) {
    return function ( dispatch ) {
      dispatch( { type: types.SET_STATE, attrs: { saveStatus: "saving" } } );
      dispatch( actions.saveObservations( ) );
    };
  }

  static saveObservations( ) {
    return function ( dispatch, getState ) {
      const s = getState( );
      const stateCounts = { pending: 0, saving: 0, saved: 0, failed: 0 };
      let nextToSave;
      _.each( s.dragDropZone.obsCards, ( c ) => {
        stateCounts[c.save_state] = stateCounts[c.save_state] || 0;
        stateCounts[c.save_state] += 1;
        if ( c.save_state === "pending" && !nextToSave ) {
          nextToSave = c;
        }
      } );
      dispatch( { type: types.SET_STATE, attrs: { saveCounts: stateCounts } } );
      if ( nextToSave && stateCounts.saving < s.dragDropZone.maximumNumberOfUploads ) {
        nextToSave.save( dispatch );
      } else if ( nextToSave ) {
        // waiting for existing uploads to finish;
      } else if ( stateCounts.pending === 0 && stateCounts.saving === 0 ) {
        window.location = `/observations/${CURRENT_USER.login}`;
      }
    };
  }

  static uploadImages( ) {
    return function ( dispatch, getState ) {
      const s = getState( );
      const stateCounts = { pending: 0, uploading: 0, uploaded: 0, failed: 0 };
      let nextToUpload;
      _.each( s.dragDropZone.obsCards, ( c ) => {
        _.each( c.files, ( f ) => {
          stateCounts[f.upload_state] = stateCounts[f.upload_state] || 0;
          stateCounts[f.upload_state] += 1;
          if ( f.upload_state === "pending" && !nextToUpload ) {
            nextToUpload = { card: c, file: f };
          }
        } );
      } );
      if ( nextToUpload && stateCounts.uploading < s.dragDropZone.maximumNumberOfUploads &&
           !( stateCounts.uploading === 1 && stateCounts.uploaded === 0 ) ) {
        nextToUpload.card.upload( nextToUpload.file, dispatch );
      } else if ( nextToUpload ) {
        // waiting for existing uploads to finish
      }
    };
  }
};

export default actions;
