import _ from "lodash";
import * as types from "../constants/constants";
import React from "react";
import inaturalistjs from "inaturalistjs";
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
    return function ( dispatch ) {
      const firstKey = _.first( _.keys( obsCards ) );
      dispatch( { type: types.APPEND_OBS_CARDS, obsCards } );
      // select the first card in any new batch
      dispatch( actions.selectObsCards( { [firstKey]: true } ) );
    };
  }

  static appendFiles( files ) {
    return { type: types.APPEND_FILES, files };
  }

  static updateFile( file, attrs ) {
    return { type: types.UPDATE_FILE, file, attrs };
  }

  static removeFile( file ) {
    return { type: types.REMOVE_FILE, file };
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

  static appendToSelectedObsCards( attrs ) {
    return { type: types.APPEND_TO_SELECTED_OBS_CARDS, attrs };
  }

  static removeFromSelectedObsCards( attrs ) {
    return { type: types.REMOVE_FROM_SELECTED_OBS_CARDS, attrs };
  }

  static removeSelected( ) {
    return { type: types.REMOVE_SELECTED };
  }

  static selectAll( ) {
    return { type: types.SELECT_ALL };
  }

  static createBlankObsCard( ) {
    return function ( dispatch, getState ) {
      dispatch( { type: types.CREATE_BLANK_OBS_CARD } );
      const s = getState( );
      const lastKey = _.last( _.keys( s.dragDropZone.obsCards ) );
      // select the blank card
      dispatch( actions.selectObsCards( { [lastKey]: true } ) );
    };
  }

  static readFileExif( file ) {
    return function ( dispatch ) {
      file.readExif( ).then( metadata => {
        dispatch( actions.updateFile( file, { metadata } ) );
      } );
    };
  }

  static onFileDrop( droppedFiles, e ) {
    return function ( dispatch ) {
      if ( droppedFiles.length === 0 ) { return; }
      // skip drops onto cards
      if ( $( "ul.obs li" ).has( e.nativeEvent.target ).length > 0 ) { return; }
      const obsCards = { };
      const files = { };
      let i = 0;
      const startTime = new Date( ).getTime( );
      droppedFiles.forEach( f => {
        if ( f.type.match( /^image\// ) ) {
          const id = ( startTime + i );
          const obsCard = new ObsCard( { id } );
          files[id] = DroppedFile.fromFile( f, { id, cardID: id, sort: id } );
          obsCards[obsCard.id] = obsCard;
          dispatch( actions.readFileExif( files[id] ) );
          i += 1;
        }
      } );
      if ( Object.keys( obsCards ).length > 0 ) {
        dispatch( actions.appendObsCards( obsCards ) );
        dispatch( actions.appendFiles( files ) );
        dispatch( actions.uploadImages( ) );
      }
    };
  }

  static onFileDropOnCard( droppedFiles, e, obsCard ) {
    return function ( dispatch ) {
      if ( droppedFiles.length === 0 ) { return; }
      const files = { };
      let i = 0;
      const startTime = new Date( ).getTime( );
      droppedFiles.forEach( f => {
        if ( f.type.match( /^image\// ) ) {
          const id = ( startTime + i );
          files[id] = DroppedFile.fromFile( f, { id, cardID: obsCard.id, sort: id } );
          dispatch( actions.readFileExif( files[id] ) );
          i += 1;
        }
      } );
      if ( Object.keys( files ).length > 0 ) {
        dispatch( actions.appendFiles( files ) );
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
      if ( attrs.saveState ) {
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

      let i = 0;
      const startTime = new Date( ).getTime( );
      _.each( obsCards, c => {
        if ( c.id !== targetID ) {
          _.each( c.files, f => {
            const id = ( startTime + i );
            dispatch( actions.updateFile( f, { cardID: targetID, sort: id } ) );
            i += 1;
          } );
          dispatch( { type: types.REMOVE_OBS_CARD, obsCard: c } );
        }
      } );
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

  static confirmRemoveFile( file ) {
    return function ( dispatch ) {
      if ( file.uploadState === "failed" ) {
        dispatch( actions.removeFile( file ) );
      } else {
        dispatch( actions.setState( { confirmModal: {
          show: true,
          confirmClass: "danger",
          confirmText: I18n.t( "remove" ),
          message: I18n.t( "are_you_sure_remove_photo" ),
          onConfirm: () => dispatch( actions.removeFile( file ) )
        } } ) );
      }
    };
  }

  static movePhoto( photo, toObsCard ) {
    return function ( dispatch ) {
      const time = new Date( ).getTime( );
      dispatch( actions.updateFile( photo.file, { cardID: toObsCard.id, sort: time } ) );

      const fromCard = new ObsCard( Object.assign( { }, photo.obsCard ) );
      delete fromCard.files[photo.file.id];
      // the card from where the photo was move can be removed if it has no data
      // or if its data is untouched from when it was imported
      if ( fromCard.blank( ) || ( _.isEmpty( fromCard.files ) && !fromCard.modified ) ) {
        dispatch( actions.removeObsCard( fromCard ) );
      }
    };
  }

  static newCardFromPhoto( photo ) {
    return function ( dispatch ) {
      const time = new Date( ).getTime( );
      const obsCards = { [time]: new ObsCard( { id: time } ) };
      dispatch( actions.appendObsCards( obsCards ) );
      dispatch( actions.updateFile( photo.file, { cardID: time, sort: time } ) );

      const fromCard = new ObsCard( Object.assign( { }, photo.obsCard ) );
      delete fromCard.files[photo.file.id];
      // the card from where the photo was move can be removed if it has no data
      // or if its data is untouched from when it was imported
      if ( fromCard.blank( ) || ( _.isEmpty( fromCard.files ) && !fromCard.modified ) ) {
        dispatch( actions.removeObsCard( fromCard ) );
      }
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
            confirmText: I18n.t( "ok" ),
            message: I18n.t( "you_appear_offline_try_again" )
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
        if ( !failed && c.files.length === 0 && !c.taxon_id && !c.species_guess ) {
          failed = true;
        }
      } );
      if ( failed ) {
        dispatch( actions.setState( { confirmModal: {
          show: true,
          cancelText: I18n.t( "go_back" ),
          confirmText: I18n.t( "continue" ),
          message: I18n.t( "you_are_submitting_obs_without_photos_and_names" ),
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
        if ( !failed && ( !c.date || ( !c.latitude && !c.locality_notes ) ) ) {
          failed = true;
        }
      } );
      if ( failed ) {
        dispatch( actions.setState( { confirmModal: {
          show: true,
          cancelText: I18n.t( "go_back" ),
          confirmText: I18n.t( "continue" ),
          message: I18n.t( "you_are_submitting_obs_with_no_date_or_no_location" ),
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
      if ( s.dragDropZone.saveStatus !== "saving" ) { return; }
      if ( util.countPending( s.dragDropZone.files ) > 0 ) { return; }
      const stateCounts = { pending: 0, saving: 0, saved: 0, failed: 0 };
      let nextToSave;
      _.each( s.dragDropZone.obsCards, c => {
        stateCounts[c.saveState] = stateCounts[c.saveState] || 0;
        stateCounts[c.saveState] += 1;
        if ( c.saveState === "pending" && !nextToSave ) {
          nextToSave = c;
        }
      } );
      dispatch( { type: types.SET_STATE, attrs: { saveCounts: stateCounts } } );
      if ( nextToSave && stateCounts.saving < s.dragDropZone.maximumNumberOfUploads ) {
        nextToSave.save( dispatch );
      } else if ( nextToSave ) {
        // waiting for existing uploads to finish;
      } else if ( stateCounts.pending === 0 && stateCounts.saving === 0 ) {
        dispatch( actions.finalizeSave( ) );
      }
    };
  }

  static finalizeSave( ) {
    return function ( dispatch, getState ) {
      const s = getState( );
      const missingProjects = { };
      _.each( s.dragDropZone.obsCards, c => {
        const selectedProjetIDs = _.map( c.projects, "id" );
        let addedToProjectIDs = [];
        // fetch the set of IDs that obs were actually added to
        if ( c.serverResponse && c.serverResponse.project_observations ) {
          addedToProjectIDs = _.map( c.serverResponse.project_observations, "project_id" );
        }
        // compare those IDs to the ones the user selected
        const failedProjectIDs = _.difference( selectedProjetIDs, addedToProjectIDs );
        _.each( failedProjectIDs, pid => {
          missingProjects[pid] = missingProjects[pid] ||
            { project: _.find( c.projects, p => p.id === pid ), count: 0 };
          missingProjects[pid].count += 1;
        } );
      } );
      // show a modal with the projects and counts of obs that were not added
      // otherwise go to the user's observation page
      if ( _.keys( missingProjects ).length > 0 ) {
        dispatch( actions.setState( { confirmModal: {
          show: true,
          hideCancel: true,
          confirmText: I18n.t( "continue" ),
          message: (
            <div>
              { I18n.t( "some_observations_failed" ) }
              <div className="projects">
                { _.map( missingProjects, mp => (
                  <div className="project" key={ mp.project.id }>
                    <span className="title">{ mp.project.title }</span>
                    <span className="count">
                      { I18n.t( "x_observations_failed", { count: mp.count } ) }
                    </span>
                  </div>
                ) ) }
              </div>
            </div>
          ),
          onConfirm: () => {
            window.location = `/observations/${CURRENT_USER.login}`;
          }
        } } ) );
      } else {
        window.location = `/observations/${CURRENT_USER.login}`;
      }
    };
  }

  static uploadImages( ) {
    return function ( dispatch, getState ) {
      const s = getState( );
      const stateCounts = { pending: 0, uploading: 0, uploaded: 0, failed: 0 };
      let nextToUpload;
      _.each( s.dragDropZone.files, ( f ) => {
        stateCounts[f.uploadState] = stateCounts[f.uploadState] || 0;
        stateCounts[f.uploadState] += 1;
        if ( f.uploadState === "pending" && !nextToUpload ) {
          nextToUpload = f;
        }
      } );
      if ( nextToUpload && stateCounts.uploading < s.dragDropZone.maximumNumberOfUploads ) {
        dispatch( actions.uploadImage( nextToUpload ) );
      } else if ( nextToUpload ) {
        // waiting for existing uploads to finish
      } else {
        dispatch( actions.saveObservations( ) );
      }
    };
  }

  static uploadImage( file ) {
    return function ( dispatch ) {
      dispatch( actions.updateFile( file, { uploadState: "uploading" } ) );
      inaturalistjs.photos.create( { file: file.file }, { same_origin: true } ).then( r => {
        const serverMetadata = file.additionalPhotoMetadata( r );
        dispatch( actions.updateFile( file, {
          uploadState: "uploaded", photo: r, serverMetadata } ) );
        setTimeout( ( ) => {
          dispatch( actions.uploadImages( ) );
        }, 100 );
      } ).catch( e => {
        console.log( "Upload failed:", e );
        dispatch( actions.updateFile( file, { uploadState: "failed" } ) );
        setTimeout( ( ) => {
          dispatch( actions.uploadImages( ) );
        }, 100 );
      } );
    };
  }

};

export default actions;
