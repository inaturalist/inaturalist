import _ from "lodash";
import * as types from "../constants/constants";
import DroppedFile from "../models/dropped_file";
import ObsCard from "../models/obs_card";
import util from "../models/util";

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

  static removeSelected( ) {
    return { type: types.REMOVE_SELECTED };
  }

  static selectAll( ) {
    return { type: types.SELECT_ALL };
  }

  static createBlankObsCard( ) {
    return { type: types.CREATE_BLANK_OBS_CARD };
  }

  static onFileDrop( droppedFiles, e ) {
    return function ( dispatch ) {
      if ( droppedFiles.length === 0 ) { return; }
      // skip drops onto cards
      if ( $( "ul.obs li" ).has( e.nativeEvent.target ).length > 0 ) { return; }
      const obsCards = { };
      let i = 0;
      const startTime = new Date( ).getTime( );
      droppedFiles.forEach( f => {
        if ( f.type.match( /^image\// ) ) {
          const id = ( startTime + i );
          const obsCard = new ObsCard( { id } );
          obsCard.files[id] = DroppedFile.fromFile( f, id );
          obsCards[obsCard.id] = obsCard;
          i += 1;
        }
      } );
      if ( Object.keys( obsCards ).length > 0 ) {
        dispatch( actions.appendObsCards( obsCards ) );
        dispatch( actions.uploadImages( ) );
      }
    };
  }

  static onFileDropOnCard( droppedFiles, e, obsCard ) {
    return function ( dispatch ) {
      if ( droppedFiles.length === 0 ) { return; }
      const files = Object.assign( { }, obsCard.files );
      let i = 0;
      const startTime = new Date( ).getTime( );
      droppedFiles.forEach( f => {
        if ( f.type.match( /^image\// ) ) {
          const id = ( startTime + i );
          files[id] = DroppedFile.fromFile( f, id );
          i += 1;
        }
      } );
      if ( Object.keys( files ).length !== Object.keys( obsCard.files ).length ) {
        dispatch( actions.updateObsCard( obsCard, {
          files,
          dispatch
        } ) );
        dispatch( actions.uploadImages( ) );
      }
    };
  }

  static confirmRemoveSelected( ) {
    return function ( dispatch, getState ) {
      const s = getState( );
      const count = _.keys( s.dragDropZone.selectedObsCards ).length;
      if ( count > 0 ) {
        dispatch( actions.setState( { removeModal: {
          show: true,
          count
        } } ) );
      }
    };
  }

  static confirmRemoveObsCard( obsCard ) {
    return function ( dispatch ) {
      if ( obsCard.blank( ) ) {
        dispatch( { type: types.REMOVE_OBS_CARD, obsCard } );
      } else {
        dispatch( actions.setState( { removeModal: {
          show: true,
          count: 1,
          obsCard
        } } ) );
      }
    };
  }

  static updateObsCard( obsCard, attrs ) {
    return function ( dispatch ) {
      dispatch( { type: types.UPDATE_OBS_CARD, obsCard, attrs } );
      if ( attrs.save_state ) {
        setTimeout( ( ) => {
          dispatch( actions.saveObservations( ) );
        }, 100 );
      }
    };
  }

  static mergeObsCards( obsCards, targetCard ) {
    return function ( dispatch ) {
      const ids = _.keys( obsCards );
      const targetIDString = targetCard ? targetCard.id : _.min( ids );
      const targetID = parseInt( targetIDString, 10 );
      const mergedFiles = Object.assign( { }, obsCards[targetID].files );

      let i = 0;
      const startTime = new Date( ).getTime( );
      _.each( obsCards, c => {
        if ( c.id !== targetID ) {
          _.each( c.files, f => {
            const id = ( startTime + i );
            mergedFiles[id] = new DroppedFile( Object.assign( { }, f, { id } ) );
            i += 1;
          } );
          dispatch( { type: types.REMOVE_OBS_CARD, obsCard: c } );
        }
      } );
      dispatch( actions.updateObsCard( obsCards[targetID], { files: mergedFiles } ) );
      dispatch( actions.selectObsCards( { [targetID]: true } ) );
    };
  }

  static combineSelected( ) {
    return function ( dispatch, getState ) {
      const s = getState( );
      const count = _.keys( s.dragDropZone.selectedObsCards ).length;
      if ( count > 1 ) {
        dispatch( actions.mergeObsCards( s.dragDropZone.selectedObsCards ) );
      }
    };
  }

  static confirmRemoveFile( file, obsCard ) {
    return function ( dispatch ) {
      dispatch( actions.setState( { confirmModal: {
        show: true,
        confirmClass: "danger",
        confirmText: "Remove",
        message: "Are you sure you want to remove this photo?",
        onConfirm: () => dispatch( actions.removeFile( file, obsCard ) )
      } } ) );
    };
  }

  static removeFile( file, obsCard ) {
    return function ( dispatch ) {
      const files = Object.assign( { }, obsCard.files );
      delete files[file.id];
      dispatch( actions.updateObsCard( obsCard, { files } ) );
    };
  }

  static movePhoto( photo, toObsCard ) {
    return function ( dispatch ) {
      const fromFiles = Object.assign( { }, photo.obsCard.files );
      const toFiles = Object.assign( { }, toObsCard.files );

      const time = new Date( ).getTime( );
      toFiles[time] = new DroppedFile( Object.assign( { }, photo.file, { id: time } ) );
      delete fromFiles[photo.file.id];

      dispatch( actions.updateObsCard( photo.obsCard, { files: fromFiles } ) );
      dispatch( actions.updateObsCard( toObsCard, { files: toFiles } ) );
      const fromCard = new ObsCard( Object.assign( { }, photo.obsCard ) );
      fromCard.files = fromFiles;
      if ( fromCard.blank( ) ) {
        dispatch( actions.removeObsCard( fromCard ) );
      }
    };
  }

  static newCardFromPhoto( photo ) {
    return function ( dispatch ) {
      const fromFiles = Object.assign( { }, photo.obsCard.files );
      const time = new Date( ).getTime( );
      const obsCard = new ObsCard( { id: time } );
      obsCard.files[time] = new DroppedFile( Object.assign( { }, photo.file, { id: time } ) );
      delete fromFiles[photo.file.id];
      dispatch( actions.updateObsCard( photo.obsCard, { files: fromFiles } ) );
      dispatch( actions.appendObsCards( { [obsCard.id]: obsCard } ) );
      const fromCard = new ObsCard( Object.assign( { }, photo.obsCard ) );
      fromCard.files = fromFiles;
      if ( fromCard.blank( ) ) {
        dispatch( actions.removeObsCard( fromCard ) );
      }
    };
  }

  static updateObsCardFile( obsCard, file, attrs ) {
    return function ( dispatch ) {
      dispatch( { type: types.UPDATE_OBS_CARD_FILE, obsCard, file, attrs } );
      setTimeout( ( ) => {
        dispatch( actions.uploadImages( ) );
      }, 100 );
    };
  }

  static trySubmitObservations( ) {
    return function ( dispatch ) {
      util.isOnline( online => {
        if ( online ) {
          dispatch( actions.submitCheckNoPhotoNoID( ) );
        } else {
          dispatch( actions.setState( { confirmModal: {
            show: true,
            hideCancel: true,
            confirmText: "OK",
            message:
              "You appear to be offline. Please try again when you are connected to the Internet."
          } } ) );
        }
      } );
    };
  }

  static submitCheckNoPhotoNoID( ) {
    return function ( dispatch, getState ) {
      const s = getState( );
      let failed;
      _.each( s.dragDropZone.obsCards, c => {
        if ( !failed && c.uploadedFiles( ).length === 0 && !c.taxon_id && !c.species_guess ) {
          failed = true;
        }
      } );
      if ( failed ) {
        dispatch( actions.setState( { confirmModal: {
          show: true,
          cancelText: "Go Back",
          confirmText: "Continue",
          message:
            "You are submitting observations without photos and taxon names. " +
            "These observations will very difficult to accurately identify",
          onConfirm: () => {
            setTimeout( () =>
              dispatch( actions.submitCheckPhotoNoDateOrLocation( ) ), 50 );
          }
        } } ) );
      } else {
        dispatch( actions.submitCheckPhotoNoDateOrLocation( ) );
      }
    };
  }

  static submitCheckPhotoNoDateOrLocation( ) {
    return function ( dispatch, getState ) {
      const s = getState( );
      let failed;
      _.each( s.dragDropZone.obsCards, c => {
        if ( !failed && c.uploadedFiles( ).length > 0 &&
             ( !c.date || !c.latitude && !c.locality_notes ) ) {
          failed = true;
        }
      } );
      if ( failed ) {
        dispatch( actions.setState( { confirmModal: {
          show: true,
          cancelText: "Go Back",
          confirmText: "Continue",
          message:
            "You are submitting observations with photos but without date or location",
          onConfirm: () => {
            dispatch( actions.submitObservations( ) );
          }
        } } ) );
      } else {
        dispatch( actions.submitObservations( ) );
      }
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
      _.each( s.dragDropZone.obsCards, c => {
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
      if ( nextToUpload && stateCounts.uploading < s.dragDropZone.maximumNumberOfUploads ) {
        nextToUpload.card.upload( nextToUpload.file, dispatch );
      } else if ( nextToUpload ) {
        // waiting for existing uploads to finish
      }
    };
  }
};

export default actions;
