import _ from "lodash";
import update from "immutability-helper";
import * as types from "../constants/constants";
import ObsCard from "../models/obs_card";

const defaultState = {
  obsCards: { },
  obsPositions: [],
  files: { },
  numberOfUploads: 0,
  maximumNumberOfUploads: 3,
  saveCounts: {
    pending: 0,
    saving: 0,
    saved: 0,
    failed: 0
  },
  locationChooser: { show: false, fitCurrentCircle: false },
  removeModal: { show: false },
  confirmModal: { show: false },
  photoViewer: { show: false },
  selectedObsCards: { }
};

const dragDropZone = ( state = defaultState, action ) => {
  switch ( action.type ) {
    case types.APPEND_OBS_CARDS: {
      const newCardIds = _.without(
        _.map( action.obsCards, ( card, id ) => parseInt( id, 0 ) ),
        state.obsPositions
      );
      return update( state, {
        obsCards: { $merge: action.obsCards },
        obsPositions: {
          $push: newCardIds
        }
      } );
    }

    case types.APPEND_FILES: {
      let updatedState = update( state, {
        files: { $merge: action.files }
      } );
      const cardIDs = _.zipObject( _.map( action.files, "cardID" ), "true" );
      const time = new Date( ).getTime( );
      // heavy handed way to (re)set files associated with cards
      _.each( updatedState.obsCards, ( obsCard, id ) => {
        const attrs = { };
        attrs.files = _.pickBy( updatedState.files, f => f.cardID === obsCard.id );
        // the card associated with a new file should be 'updated'
        if ( cardIDs[obsCard.id] ) {
          attrs.updatedAt = time;
          attrs.galleryIndex = 1;
          attrs.validationErrors = obsCard.validationErrors;
          if ( obsCard.validationErrors.media && _.size( attrs.files ) > 0 ) {
            delete attrs.validationErrors.media;
          }
        }
        updatedState = update( updatedState, {
          obsCards: {
            [id]: { $merge: attrs }
          }
        } );
      } );
      return updatedState;
    }

    case types.UPDATE_OBS_CARD: {
      const obsCard = state.obsCards[action.obsCard.id];
      if ( obsCard === undefined ) {
        return state;
      }
      const { attrs } = action;
      // reset the gallery to the first photo when a new photo is added
      if ( action.attrs.files ) { attrs.galleryIndex = 1; }
      const keys = _.keys( attrs );
      if (
        _.difference( keys, ["saveState", "galleryIndex", "files"] ).length > 0
        && attrs.modified !== false
      ) {
        attrs.modified = true;
      }
      // if false, keep it false, or don't override the value if modified is true
      if ( attrs.modified === false ) { delete attrs.modified; }
      attrs.validationErrors = obsCard.validationErrors;
      if ( obsCard.validationErrors.files && attrs.files.length > 0 ) {
        delete attrs.validationErrors.files;
      }
      if ( obsCard.validationErrors.taxon && ( attrs.taxon_id || attrs.species_guess ) ) {
        delete attrs.validationErrors.taxon;
      }
      if ( obsCard.validationErrors.date && attrs.date ) {
        delete attrs.validationErrors.date;
      }
      if ( obsCard.validationErrors.location && ( attrs.latitude || attrs.locality_notes ) ) {
        delete attrs.validationErrors.location;
      }

      let newState = update( state, {
        obsCards: {
          [action.obsCard.id]: {
            $merge: Object.assign( { }, attrs, {
              updatedAt: new Date( ).getTime( ),
              changedFields: Object.assign( { }, action.obsCard.changedFields, attrs )
            } )
          }
        }
      } );

      if ( state.selectedObsCards[action.obsCard.id] ) {
        newState = update( newState, {
          selectedObsCards: { [action.obsCard.id]: { $set: newState.obsCards[action.obsCard.id] } }
        } );
      }
      return newState;
    }

    case types.UPDATE_FILE: {
      if ( state.files[action.file.id] === undefined ) {
        return state;
      }
      const time = new Date( ).getTime( );
      let updatedState = update( state, {
        files: {
          [action.file.id]: { $merge: action.attrs }
        }
      } );
      const { cardID } = updatedState.files[action.file.id];
      const card = updatedState.obsCards[cardID];
      // the card the file is currently associated with
      if ( card ) {
        const cardUpdates = Object.assign( { updatedAt: time },
          card.newMetadataFromFile( updatedState.files[action.file.id] ) );
        updatedState = update( updatedState, {
          obsCards: { [cardID]: { $merge: cardUpdates } }
        } );
        if ( state.selectedObsCards[card.id] ) {
          updatedState = update( updatedState, {
            selectedObsCards: { [card.id]: { $set: updatedState.obsCards[card.id] } }
          } );
        }
      }
      // the file was previously associated with another card that still exists,
      // so update that cards updatedAt time
      if ( action.file.cardID !== cardID && updatedState.obsCards[action.file.cardID] ) {
        updatedState = update( updatedState, {
          obsCards: { [action.file.cardID]: { $merge: { updatedAt: time } } }
        } );
      }
      _.each( updatedState.obsCards, ( obsCard, id ) => {
        updatedState.obsCards[id].files = _.pickBy(
          updatedState.files,
          f => f.cardID === obsCard.id
        );
      } );
      return updatedState;
    }

    case types.UPDATE_SELECTED_OBS_CARDS: {
      const time = new Date( ).getTime( );
      let modified = Object.assign( { }, state.obsCards );
      _.each( state.selectedObsCards, c => {
        modified = update( modified, {
          [c.id]: {
            $merge: Object.assign( action.attrs, {
              updatedAt: time,
              changedFields: Object.assign( { }, c.changedFields, action.attrs )
            } )
          }
        } );
      } );
      return Object.assign( { }, state, {
        obsCards: modified,
        selectedObsCards: _.pick( modified, _.keys( state.selectedObsCards ) )
      } );
    }

    case types.APPEND_TO_SELECTED_OBS_CARDS: {
      const time = new Date( ).getTime( );
      let modified = Object.assign( { }, state.obsCards );
      _.each( action.attrs, ( v, k ) => {
        _.each( state.selectedObsCards, c => {
          if ( Array.isArray( c[k] ) ) {
            modified = update( modified, {
              [c.id]: {
                $merge: {
                  [k]: _.uniqBy( _.flatten( c[k].concat( v ) ), uv => {
                    if ( uv.observation_field_id ) {
                      return uv.observation_field_id;
                    }
                    if ( uv.id ) {
                      return uv.id;
                    }
                    return uv;
                  } ),
                  updatedAt: time
                }
              }
            } );
          }
        } );
      } );
      return Object.assign( { }, state, {
        obsCards: modified,
        selectedObsCards: _.pick( modified, _.keys( state.selectedObsCards ) )
      } );
    }

    case types.REMOVE_FROM_SELECTED_OBS_CARDS: {
      const time = new Date( ).getTime( );
      let modified = Object.assign( { }, state.obsCards );
      _.each( action.attrs, ( v, k ) => {
        _.each( state.selectedObsCards, c => {
          if ( Array.isArray( c[k] ) ) {
            modified = update( modified, {
              [c.id]: {
                $merge: {
                  [k]: _.uniq( _.difference( c[k], _.flatten( [v] ) ) ),
                  updatedAt: time
                }
              }
            } );
          }
        } );
      } );
      return Object.assign( { }, state, {
        obsCards: modified,
        selectedObsCards: _.pick( modified, _.keys( state.selectedObsCards ) )
      } );
    }

    case types.SELECT_OBS_CARDS: {
      let modified = Object.assign( { }, state.obsCards );
      _.each( modified, ( card, k ) => {
        if ( action.ids[modified[k].id] ) {
          if ( !modified[k].selected ) {
            modified = update( modified, {
              [k]: { $merge: { selected: true } }
            } );
          }
        } else if ( modified[k].selected ) {
          modified = update( modified, {
            [k]: { $merge: { selected: false } }
          } );
        }
      } );
      const newState = {
        obsCards: modified,
        selectedObsCards: _.pick( modified, _.keys( action.ids ) )
      };
      if ( _.isEmpty( newState.selectedObsCards ) ) {
        newState.observationField = null;
        newState.observationFieldTaxon = null;
        newState.observationFieldValue = null;
        newState.observationFieldSelectedDate = null;
      }
      return Object.assign( { }, state, newState );
    }

    case types.SELECT_ALL: {
      let modified = Object.assign( { }, state.obsCards );
      _.each( modified, c => {
        modified = update( modified, {
          [c.id]: { $merge: { selected: true } }
        } );
      } );
      return Object.assign( { }, state, {
        obsCards: modified,
        selectedObsCards: modified
      } );
    }

    case types.REMOVE_OBS_CARD: {
      const cards = Object.assign( { }, state.obsCards );
      const ids = Object.assign( { }, state.selectedIDs );
      const files = Object.assign( { }, state.files );
      delete cards[action.obsCard.id];
      delete ids[action.obsCard.id];
      _.each( files, file => {
        if ( file.cardID.toString( ) === action.obsCard.id.toString( ) ) {
          if ( file.preview ) {
            window.URL.revokeObjectURL( file.preview );
          }
          delete files[file.id];
        }
      } );
      return Object.assign( { }, state, {
        obsCards: cards,
        obsPositions: _.filter( state.obsPositions, id => cards[id] ),
        selectedIDs: ids,
        files
      } );
    }

    case types.REMOVE_FILE: {
      let updatedState = Object.assign( { }, state );
      const card = updatedState.obsCards[updatedState.files[action.file.id].cardID];
      const time = new Date( ).getTime( );
      // bump updatedAt for this file's card
      if ( card ) {
        updatedState = update( updatedState, {
          obsCards: {
            [card.id]: { $merge: { updatedAt: time, galleryIndex: 1 } }
          }
        } );
      }
      if ( updatedState.files[action.file.id] && updatedState.files[action.file.id].preview ) {
        window.URL.revokeObjectURL( updatedState.files[action.file.id].preview );
      }
      delete updatedState.files[action.file.id];
      // reset all card file associations
      _.each( updatedState.obsCards, ( obsCard, id ) => {
        updatedState.obsCards[id].files = _.pickBy(
          updatedState.files,
          f => f.cardID === obsCard.id
        );
      } );
      return Object.assign( { }, state, {
        obsCards: updatedState.obsCards,
        files: updatedState.files
      } );
    }

    case types.REMOVE_SELECTED: {
      const modified = Object.assign( { }, state.obsCards );
      const files = Object.assign( { }, state.files );
      _.each( state.selectedObsCards, ( v, id ) => {
        delete modified[id];
        _.each( files, file => {
          if ( file.cardID.toString( ) === id.toString( ) ) {
            if ( file.preview ) {
              window.URL.revokeObjectURL( file.preview );
            }
            delete files[file.id];
          }
        } );
      } );
      return Object.assign( { }, state, {
        obsCards: modified,
        files,
        selectedObsCards: { },
        obsPositions: _.filter( state.obsPositions, id => modified[id] )
      } );
    }

    case types.CREATE_BLANK_OBS_CARD: {
      const obsCard = new ObsCard( );
      return update( state, {
        obsCards: {
          [obsCard.id]: { $set: obsCard }
        },
        obsPositions: {
          $push: [parseInt( obsCard.id, 0 )]
        }
      } );
    }

    case types.INSERT_CARDS_BEFORE: {
      let newPositions = [];
      const cardIds = action.cardIds.map( cardId => parseInt( cardId, 0 ) );
      _.each( state.obsPositions, cardId => {
        if ( cardId === action.beforeCardId ) {
          newPositions = newPositions.concat( cardIds );
        }
        if ( cardIds.indexOf( cardId ) < 0 ) {
          newPositions.push( cardId );
        }
      } );
      if ( !action.beforeCardId || action.beforeCardId === undefined ) {
        newPositions = newPositions.concat( cardIds );
      }
      return Object.assign( { }, state, {
        obsPositions: newPositions
      } );
    }

    case types.SET_STATE: {
      let modified = Object.assign( { }, state );
      _.each( action.attrs, ( val, attr ) => {
        modified = update( modified, {
          [attr]: { $set: val }
        } );
      } );
      return modified;
    }

    case types.UPDATE_STATE: {
      let modified = Object.assign( { }, state );
      _.each( action.attrs, ( val, attr ) => {
        modified = update( modified, {
          [attr]: { $merge: val }
        } );
      } );
      return modified;
    }

    default:
      return state;
  }
};

export default dragDropZone;
