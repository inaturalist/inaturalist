import _ from "lodash";
import React from "react";
import inaturalistjs from "inaturalistjs";
import * as types from "../constants/constants";
import DroppedFile from "../models/dropped_file";
import ObsCard from "../models/obs_card";
import util from "../models/util";
import { resizeUpload } from "../../../shared/util";
import RejectedFilesError from "../../../shared/components/rejected_files_error";

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

  static fileCounts( files ) {
    return {
      photos: _.filter( files, f => /^image\//.test( f.type ) ).length,
      sounds: _.filter( files, f => /^audio\//.test( f.type ) ).length
    };
  }

  static enforceLimit( src, dest ) {
    const cardFileDropLimit = 20;
    const obeysLimit = ( src + dest <= cardFileDropLimit );
    return function ( dispatch ) {
      if ( !obeysLimit ) {
        dispatch( actions.setState( {
          confirmModal: {
            show: true,
            message: I18n.t( "observations_can_only_have_n_photos", { limit: cardFileDropLimit } ),
            confirmText: I18n.t( "ok" ),
            hideCancel: true
          }
        } ) );
      }
      return obeysLimit;
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

  static insertCardsBefore( cardIds, beforeCardId ) {
    return {
      type: types.INSERT_CARDS_BEFORE,
      cardIds,
      beforeCardId
    };
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

  static processNewImage( file ) {
    return function ( dispatch ) {
      dispatch( actions.createVisionThumbnail( file ) );
      dispatch( actions.readFileExif( file ) );
    };
  }

  static readFileExif( file ) {
    return function ( dispatch ) {
      file.readExif( ).then( metadata => {
        dispatch( actions.updateFile( file, { metadata } ) );
      } );
    };
  }

  static createVisionThumbnail( file ) {
    return function ( dispatch ) {
      resizeUpload( file.file, { blob: true }, resizedFile => {
        dispatch( actions.updateFile( file, { visionThumbnail: resizedFile } ) );
      } );
    };
  }

  static onFileDrop( droppedFiles, options = {} ) {
    return function ( dispatch ) {
      if ( droppedFiles.length === 0 ) { return; }
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
          dispatch( actions.processNewImage( files[id] ) );
          i += 1;
        } else if ( f.type.match( /^audio\// ) ) {
          const id = ( startTime + i );
          const obsCard = new ObsCard( { id } );
          files[id] = DroppedFile.fromFile( f, { id, cardID: id, sort: id } );
          obsCards[obsCard.id] = obsCard;
          i += 1;
        }
      } );
      if ( Object.keys( obsCards ).length > 0 ) {
        dispatch( actions.appendObsCards( obsCards ) );
        dispatch( actions.appendFiles( files ) );
        dispatch( actions.uploadFiles( ) );
        if ( options.beforeCardId ) {
          dispatch( actions.insertCardsBefore(
            Object.keys( obsCards ),
            options.beforeCardId
          ) );
        }
      }
    };
  }

  static onFileDropOnCard( droppedFiles, obsCard ) {
    return function ( dispatch ) {
      if ( droppedFiles.length === 0 ) { return; }
      const { photos: targetPhotos, sounds: targetSounds } = actions.fileCounts( obsCard.files );
      const { photos: droppedPhotos, sounds: droppedSounds } = actions.fileCounts( droppedFiles );
      if ( !dispatch( actions.enforceLimit( droppedPhotos, targetPhotos ) ) ) { return; }
      if ( !dispatch( actions.enforceLimit( droppedSounds, targetSounds ) ) ) { return; }
      const files = { };
      let i = 0;
      const startTime = new Date( ).getTime( );
      droppedFiles.forEach( f => {
        if ( f.type.match( /^image\// ) ) {
          const id = ( startTime + i );
          files[id] = DroppedFile.fromFile( f, { id, cardID: obsCard.id, sort: id } );
          dispatch( actions.processNewImage( files[id] ) );
          i += 1;
        } else if ( f.type.match( /^audio\// ) ) {
          const id = ( startTime + i );
          files[id] = DroppedFile.fromFile( f, { id, cardID: obsCard.id, sort: id } );
          i += 1;
        }
      } );
      if ( Object.keys( files ).length > 0 ) {
        dispatch( actions.appendFiles( files ) );
        dispatch( actions.uploadFiles( ) );
      }
    };
  }

  static confirmRemoveSelected( ) {
    return function ( dispatch, getState ) {
      const s = getState( );
      const count = _.keys( s.dragDropZone.selectedObsCards ).length;
      if ( count > 0 ) {
        dispatch( actions.setState( {
          removeModal: {
            show: true,
            count
          }
        } ) );
      }
    };
  }

  static confirmRemoveObsCard( obsCard ) {
    return function ( dispatch ) {
      if ( obsCard.blank( ) ) {
        dispatch( { type: types.REMOVE_OBS_CARD, obsCard } );
      } else {
        dispatch( actions.setState( {
          removeModal: {
            show: true,
            count: 1,
            obsCard
          }
        } ) );
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
      const targetFiles = obsCards[targetID].files;
      const { photos: targetPhotos, sounds: targetSounds } = actions.fileCounts( targetFiles );
      let { remainingPhotos, remainingSounds } = { remainingPhotos: 0, remainingSounds: 0 };
      _.each( obsCards, c => {
        if ( c.id !== targetID ) {
          const { photos: toAddPhotos, sounds: toAddSounds } = actions.fileCounts( c.files );
          remainingPhotos += toAddPhotos;
          remainingSounds += toAddSounds;
        }
      } );
      if ( !dispatch( actions.enforceLimit( remainingPhotos, targetPhotos ) ) ) { return; }
      if ( !dispatch( actions.enforceLimit( remainingSounds, targetSounds ) ) ) { return; }
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

  static duplicateObsCards( obsCards ) {
    return function ( dispatch, getState ) {
      let serialId = new Date( ).getTime( );
      const { files, obsPositions } = getState( ).dragDropZone;
      const newCards = [];
      // for each obs card
      _.each( obsCards, c => {
        // make a new card
        const id = serialId;
        const newCard = new ObsCard( {
          ..._.pick( c, [
            "accuracy",
            "bounds",
            "captive",
            "date",
            "description",
            "geoprivacy",
            "latitude",
            "locality_notes",
            "longitude",
            "manualPlaceGuess",
            "modified",
            "positional_accuracy",
            "tags",
            "zoom"
          ] ),
          id
        } );
        // update that card with the old card's attributes
        dispatch( actions.appendObsCards( { [newCard.id]: newCard } ) );
        newCards.push( newCard );
        // insert the new card after the old one
        const cardPosition = obsPositions.indexOf( c.id );
        const beforeCardId = cardPosition === obsPositions.length - 1
          ? null
          : obsPositions[cardPosition + 1];
        dispatch( actions.insertCardsBefore( [newCard.id], beforeCardId ) );
        const cardFiles = _.filter( files, f => f.cardID === c.id );
        if ( cardFiles.length > 0 ) {
          const newFiles = {};
          _.each( cardFiles, cf => {
            // make a new file and update with the old file's attributes
            // TODO Make it so you don't upload a file twice. Responding to an
            // upload event should just upload all the local file records
            // associated with that upload
            if ( cf.uploadState === "uploaded" ) {
              newFiles[serialId] = new DroppedFile( {
                ..._.pick( cf, [
                  "metadata",
                  "name",
                  "photo",
                  "serverMetadata",
                  "sort",
                  "sound",
                  "type",
                  "uploadState",
                  "visionThumbnail"
                ] ),
                id: serialId,
                cardID: newCard.id
              } );
            } else {
              newFiles[serialId] = new DroppedFile( {
                ..._.pick( cf, [
                  "file",
                  "metadata",
                  "name",
                  "photo",
                  "preview",
                  "sort",
                  "sound",
                  "type",
                  "visionThumbnail"
                ] ),
                id: serialId,
                cardID: newCard.id,
                uploadState: "pending"
              } );
            }
            serialId += 1;
          } );
          dispatch( actions.appendFiles( newFiles ) );
        }
        serialId += 1;
      } );
      dispatch( actions.selectObsCards( _.reduce( newCards, ( o, card ) => {
        o[card.id] = true;
        return o;
      }, { } ) ) );
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
        dispatch( actions.setState( {
          confirmModal: {
            show: true,
            confirmClass: "danger",
            confirmText: I18n.t( "remove" ),
            message: I18n.t( "are_you_sure_remove_photo" ),
            onConfirm: () => dispatch( actions.removeFile( file ) )
          }
        } ) );
      }
    };
  }

  static movePhoto( photo, toObsCard ) {
    return function ( dispatch ) {
      const { photos: targetPhotos, sounds: targetSounds } = actions.fileCounts( toObsCard.files );
      const { photos: movedPhotos, sounds: movedSounds } = actions.fileCounts( [photo.file] );
      if ( !dispatch( actions.enforceLimit( movedPhotos, targetPhotos ) ) ) { return; }
      if ( !dispatch( actions.enforceLimit( movedSounds, targetSounds ) ) ) { return; }
      const time = new Date( ).getTime( );
      dispatch( actions.updateFile( photo.file, { cardID: toObsCard.id, sort: time } ) );

      const fromCard = new ObsCard( { ...photo.obsCard } );
      delete fromCard.files[photo.file.id];
      // the card from where the photo was move can be removed if it has no data
      // or if its data is untouched from when it was imported
      if ( fromCard.blank( ) || ( _.isEmpty( fromCard.files ) && !fromCard.modified ) ) {
        dispatch( actions.removeObsCard( fromCard ) );
      }
    };
  }

  static newCardFromMedia( media, options = {} ) {
    return function ( dispatch ) {
      const time = new Date( ).getTime( );
      const obsCards = { [time]: new ObsCard( { id: time } ) };
      dispatch( actions.appendObsCards( obsCards ) );
      dispatch( actions.updateFile( media.file, { cardID: time, sort: time } ) );
      if ( options.beforeCardId !== undefined ) {
        dispatch( actions.insertCardsBefore( [time], options.beforeCardId ) );
      }

      const fromCard = new ObsCard( { ...media.obsCard } );
      delete fromCard.files[media.file.id];
      // the card from where the photo was moved can be removed if it has no data
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
          dispatch( actions.submitCheckNoPhotoOrNoID( ) );
        } else {
          dispatch( actions.setState( {
            confirmModal: {
              show: true,
              hideCancel: true,
              confirmText: I18n.t( "ok" ),
              message: I18n.t( "you_appear_offline_try_again" )
            }
          } ) );
        }
      } );
    };
  }

  static submitCheckNoPhotoOrNoID( ) {
    return function ( dispatch, getState ) {
      const s = getState( );
      let failed;
      _.each( s.dragDropZone.obsCards, c => {
        if (
          !failed
          && ( _.size( c.files ) === 0 || ( !c.taxon_id && !c.species_guess ) )
        ) {
          failed = true;
        }
      } );
      if ( failed ) {
        dispatch( actions.setState( {
          confirmModal: {
            show: true,
            cancelText: I18n.t( "go_back" ),
            confirmText: I18n.t( "continue" ),
            title: I18n.t( "some_observations_are_missing_media_or_identifications" ),
            message: I18n.t( "some_observations_are_missing_media_or_identifications_desc" ),
            onConfirm: () => {
              setTimeout( () => dispatch( actions.submitCheckPhotoNoDateOrLocation( ) ), 50 );
            }
          }
        } ) );
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
        dispatch( actions.setState( {
          confirmModal: {
            show: true,
            cancelText: I18n.t( "go_back" ),
            confirmText: I18n.t( "continue" ),
            message: I18n.t( "you_are_submitting_obs_with_no_date_or_no_location" ),
            onConfirm: () => {
              dispatch( actions.submitObservations( ) );
            }
          }
        } ) );
      } else {
        dispatch( actions.submitObservations( ) );
      }
    };
  }

  static submitObservations( ) {
    return function ( dispatch ) {
      dispatch( { type: types.SET_STATE, attrs: { saveStatus: "saving" } } );
      dispatch( actions.selectObsCards( { } ) );
      dispatch( actions.saveObservations( ) );
    };
  }

  static saveObservations( ) {
    return function ( dispatch, getState ) {
      const s = getState( );
      if ( s.dragDropZone.saveStatus !== "saving" ) { return; }
      if ( util.countPending( s.dragDropZone.files ) > 0 ) { return; }
      const stateCounts = {
        pending: 0,
        saving: 0,
        saved: 0,
        failed: 0
      };
      let nextToSave;
      _.each( s.dragDropZone.obsPositions, cardID => {
        const c = s.dragDropZone.obsCards[cardID];
        stateCounts[c.saveState] = stateCounts[c.saveState] || 0;
        stateCounts[c.saveState] += 1;
        if ( c.saveState === "pending" && !nextToSave ) {
          nextToSave = c;
        }
      } );
      dispatch( { type: types.SET_STATE, attrs: { saveCounts: stateCounts } } );
      if ( nextToSave && stateCounts.saving < s.dragDropZone.maximumNumberOfUploads ) {
        dispatch( nextToSave.save( ) );
      } else if ( nextToSave ) {
        // waiting for existing uploads to finish;
      } else if ( stateCounts.pending === 0 && stateCounts.saving === 0 ) {
        dispatch( actions.checkProjectErrors( ) );
      }
    };
  }

  static checkProjectErrors( ) {
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
          missingProjects[pid] = missingProjects[pid]
            || { project: _.find( c.projects, p => p.id === pid ), count: 0 };
          missingProjects[pid].count += 1;
        } );
      } );
      // show a modal with the projects and counts of obs that were not added
      // otherwise go to the user's observation page
      if ( _.keys( missingProjects ).length > 0 ) {
        dispatch( actions.setState( {
          confirmModal: {
            show: true,
            hideCancel: true,
            confirmText: I18n.t( "continue" ),
            message: (
              <div>
                { I18n.t( "some_observations_failed_to_be_added" ) }
                <div className="confirm-list">
                  { _.map( missingProjects, mp => (
                    <div className="confirm-list-item" key={mp.project.id}>
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
              dispatch( actions.checkFailedUploads( ) );
            }
          }
        } ) );
      } else {
        dispatch( actions.checkFailedUploads( ) );
      }
    };
  }

  static checkFailedUploads( ) {
    return function ( dispatch, getState ) {
      const s = getState( );
      const failedCards = _.filter( s.dragDropZone.obsCards, c => c.saveState === "failed" );
      const remaining = _.pick( s.dragDropZone.obsCards, _.map( failedCards, "id" ) );
      if ( s.dragDropZone.saveCounts.failed > 0 && _.size( remaining ) > 0 ) {
        const grouped = { };
        _.each( remaining, r => {
          _.each( r.saveErrors, err => {
            grouped[err] = grouped[err] || 0;
            grouped[err] += 1;
          } );
        } );
        dispatch( actions.setState( {
          confirmModal: {
            show: true,
            confirmText: I18n.t( "stay_and_try_again" ),
            cancelText: I18n.t( "ignore_and_continue" ),
            message: (
              <div>
                { I18n.t( "some_observations_failed_to_save" ) }
                <div className="confirm-list">
                  { _.map( grouped, ( count, err ) => (
                    <div className="confirm-list-item" key={err}>
                      <span className="title">{ err }</span>
                      <span className="count">
                        { I18n.t( "x_observations_failed", { count } ) }
                      </span>
                    </div>
                  ) ) }
                </div>
              </div>
            ),
            onConfirm: ( ) => {
              dispatch( actions.setState( { obsCards: remaining, saveStatus: null } ) );
              _.each( remaining, c => {
                dispatch( actions.updateObsCard( c, { saveState: "pending" } ) );
              } );
            },
            onCancel: ( ) => {
              _.each( remaining, c => {
                dispatch( actions.updateObsCard( c, { saveState: "saved" } ) );
              } );
              dispatch( actions.confirmObservationsAvailableInAPI( ) );
            }
          }
        } ) );
      } else {
        dispatch( actions.confirmObservationsAvailableInAPI( ) );
      }
    };
  }

  static loadUsersObservationsPage( ) {
    window.location = `/observations/${CURRENT_USER.login}`;
  }

  static confirmObservationsAvailableInAPI( ) {
    return function ( dispatch ) {
      dispatch( actions.setState( { observationsAvailableStartTime: Date.now( ) } ) );
      setTimeout( ( ) => {
        dispatch( actions.checkObservationsAvaliableInAPI( ) );
      }, 2000 );
    };
  }

  // observations are stored in Elasticsearch, which makes documents available to search
  // after a refresh period. Previously we leveraged the refresh=wait_for parameter
  // when saving the last observation to request that the save didn't respond until
  // Elasticsearch performed a routine refresh. This method replaces that functionality
  // with a loop querying users observations to check the observations created this session
  // are available. Currently experimental to assess impact on Elasticsearch
  static checkObservationsAvaliableInAPI( ) {
    return async function ( dispatch, getState ) {
      const s = getState( );
      const maxSavedObservationID = _.max(
        _.map( s.dragDropZone.obsCards, o => o?.serverResponse?.id )
      );
      const timeElapsedSinceChecking = Date.now( ) - s.dragDropZone.observationsAvailableStartTime;
      // for whatever reason there were no observations saved, or the checking
      // loop has timed out, redirect the user to their observations page
      if ( !maxSavedObservationID || timeElapsedSinceChecking >= 20000 ) {
        actions.loadUsersObservationsPage( );
        return;
      }

      // query the API for the highest observation ID from this user
      const response = await inaturalistjs.observations.search( {
        user_id: CURRENT_USER.id,
        order_by: "id",
        order: "desc",
        per_page: 1,
        ttl: -1
      } );
      const maxIDFromAPI = _.first( response?.results )?.id;
      // if the highest ID from the API is the same or larger than the highest ID from this
      // upload session, the API check has passed, so redirect the user to their osbervations page
      if ( maxIDFromAPI && maxIDFromAPI >= maxSavedObservationID ) {
        actions.loadUsersObservationsPage( );
        return;
      }

      // the API is not yet reflecting uploaded observations, so wait a couple seconds and try again
      setTimeout( ( ) => {
        dispatch( actions.checkObservationsAvaliableInAPI( ) );
      }, 2000 );
    };
  }

  static uploadFiles( ) {
    return function ( dispatch, getState ) {
      const s = getState( );
      const stateCounts = {
        pending: 0,
        uploading: 0,
        uploaded: 0,
        failed: 0
      };
      let nextToUpload;
      _.each( s.dragDropZone.files, f => {
        stateCounts[f.uploadState] = stateCounts[f.uploadState] || 0;
        stateCounts[f.uploadState] += 1;
        if ( f.uploadState === "pending" && !nextToUpload ) {
          nextToUpload = f;
        }
      } );
      if ( nextToUpload && stateCounts.uploading < s.dragDropZone.maximumNumberOfUploads ) {
        if ( _.isEmpty( nextToUpload.file ) ) {
          dispatch( actions.updateFile( nextToUpload, {
            uploadState: "failed"
          } ) );
        } else if ( nextToUpload.type.match( /audio/ ) ) {
          dispatch( actions.uploadSound( nextToUpload ) );
        } else {
          dispatch( actions.uploadImage( nextToUpload ) );
        }
        dispatch( actions.uploadFiles( ) );
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
          uploadState: "uploaded",
          photo: r,
          serverMetadata
        } ) );
        setTimeout( ( ) => {
          dispatch( actions.uploadFiles( ) );
          // if the file has been uploaded and we had a preview,
          // ditch the preview to avoid memory leaks
          if ( file.preview ) {
            window.URL.revokeObjectURL( file.preview );
            dispatch( actions.updateFile( file, { preview: null } ) );
          }
        }, 100 );
      } ).catch( e => {
        dispatch( actions.handleUploadFailure(
          e,
          file,
          actions.uploadImage,
          ( ) => {
            dispatch( actions.updateFile( file, { uploadState: "failed" } ) );
            setTimeout( ( ) => {
              dispatch( actions.uploadFiles( ) );
            }, 100 );
          }
        ) );
      } );
    };
  }

  static uploadSound( file ) {
    return function ( dispatch ) {
      dispatch( actions.updateFile( file, { uploadState: "uploading" } ) );
      inaturalistjs.sounds.create( { file: file.file }, { same_origin: true } ).then( r => {
        // const serverMetadata = file.additionalPhotoMetadata( r );
        dispatch( actions.updateFile( file, {
          uploadState: "uploaded",
          sound: r,
          serverMetadata: {}
        } ) );
        setTimeout( ( ) => {
          dispatch( actions.uploadFiles( ) );
          // TODO figure out why calling window.URL.revokeObjectURL prevents the
          // sound from playing via the URL in Safari and Firefox
        }, 100 );
      } ).catch( e => {
        dispatch( actions.handleUploadFailure(
          e,
          file,
          actions.uploadSound,
          ( ) => {
            dispatch( actions.updateFile( file, { uploadState: "failed" } ) );
            setTimeout( ( ) => {
              dispatch( actions.uploadFiles( ) );
            }, 100 );
          }
        ) );
      } );
    };
  }

  static handleUploadFailure( exception, item, retryMethod, onFail ) {
    return function ( dispatch ) {
      item.saveTries = ( parseInt( item.saveTries, 10 ) || 0 ) + 1;
      if ( item.saveTries <= 10 ) {
        // wait exponentially more time each retry up to a max of 3 seconds
        const waitFor = _.min( [( 2 ** item.saveTries ) * 100, 3000] );
        setTimeout( ( ) => {
          dispatch( retryMethod( item ) );
        }, waitFor );
        return;
      }
      item.saveTries = 0;
      onFail( );
    };
  }

  static onRejectedFiles( rejectedFiles ) {
    return function ( dispatch ) {
      const message = <RejectedFilesError rejectedFiles={rejectedFiles} />;
      if ( message === null ) {
        return;
      }
      dispatch( actions.setState( {
        confirmModal: {
          show: true,
          message,
          confirmText: I18n.t( "ok" ),
          hideCancel: true
        }
      } ) );
    };
  }

  static duplicateSelected( ) {
    return function ( dispatch, getState ) {
      const s = getState( );
      dispatch( actions.duplicateObsCards( s.dragDropZone.selectedObsCards ) );
    };
  }
};

export default actions;
