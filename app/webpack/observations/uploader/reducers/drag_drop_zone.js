import _ from "lodash";
import * as types from "../constants/constants";
import update from "react-addons-update";
import ObsCard from "../models/obs_card";

const defaultState = {
  obsCards: { },
  files: { },
  numberOfUploads: 0,
  maximumNumberOfUploads: 4,
  saveCounts: { pending: 0, saving: 0, saved: 0, failed: 0 },
  locationChooser: { show: false },
  removeModal: { show: false },
  confirmModal: { show: false },
  photoViewer: { show: false },
  selectedObsCards: { }
};

const dragDropZone = ( state = defaultState, action ) => {
  switch ( action.type ) {

    case types.APPEND_OBS_CARDS: {
      return update( state, {
        obsCards: { $merge: action.obsCards }
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
        attrs.files = _.pickBy( updatedState.files, f =>
          f.cardID === obsCard.id
        );
        // the card associated with a new file should be 'updated'
        if ( cardIDs[obsCard.id] ) {
          attrs.updatedAt = time;
          attrs.galleryIndex = 1;
        }
        updatedState = update( updatedState, { obsCards: {
          [id]: { $merge: attrs }
        } } );
      } );
      return updatedState;
    }

    case types.UPDATE_OBS_CARD: {
      if ( state.obsCards[action.obsCard.id] === undefined ) {
        return state;
      }
      const attrs = action.attrs;
      // reset the gallery to the first photo when a new photo is added
      if ( action.attrs.files ) { attrs.galleryIndex = 1; }
      const keys = _.keys( attrs );
      if ( _.difference( keys, ["saveState", "galleryIndex", "files"] ).length > 0 &&
           attrs.modified !== false ) {
        attrs.modified = true;
      }
      // if false, keep it false, or don't override the value if modified is true
      if ( attrs.modified === false ) { delete attrs.modified; }
      attrs.updatedAt = new Date( ).getTime( );
      let newState = update( state, {
        obsCards: { [action.obsCard.id]: { $merge: attrs } }
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
        files: { [action.file.id]: { $merge: action.attrs } }
      } );
      const cardID = updatedState.files[action.file.id].cardID;
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
        updatedState.obsCards[id].files = _.pickBy( updatedState.files, f =>
          f.cardID === obsCard.id
        );
      } );
      return updatedState;
    }

    case types.UPDATE_SELECTED_OBS_CARDS: {
      const time = new Date( ).getTime( );
      let modified = Object.assign( { }, state.obsCards );
      _.each( state.selectedObsCards, c => {
        modified = update( modified, {
          [c.id]: { $merge: Object.assign( action.attrs, { updatedAt: time } ) }
        } );
      } );
      return Object.assign( { }, state, { obsCards: modified,
        selectedObsCards: _.pick( modified, _.keys( state.selectedObsCards ) )
      } );
    }

    case types.APPEND_TO_SELECTED_OBS_CARDS: {
      const time = new Date( ).getTime( );
      let modified = Object.assign( { }, state.obsCards );
      _.each( action.attrs, ( v, k ) => {
        _.each( state.selectedObsCards, c => {
          if ( _.isArray( c[k] ) ) {
            modified = update( modified, {
              [c.id]: { $merge: {
                [k]: _.uniqBy( _.flatten( c[k].concat( v ) ), uv => {
                  if ( uv.observation_field_id ) {
                    return uv.observation_field_id;
                  } else if ( uv.id ) {
                    return uv.id;
                  }
                  return uv;
                } ),
                updatedAt: time
              } }
            } );
          }
        } );
      } );
      return Object.assign( { }, state, { obsCards: modified,
        selectedObsCards: _.pick( modified, _.keys( state.selectedObsCards ) )
      } );
    }

    case types.REMOVE_FROM_SELECTED_OBS_CARDS: {
      const time = new Date( ).getTime( );
      let modified = Object.assign( { }, state.obsCards );
      _.each( action.attrs, ( v, k ) => {
        _.each( state.selectedObsCards, c => {
          if ( _.isArray( c[k] ) ) {
            modified = update( modified, {
              [c.id]: { $merge: {
                [k]: _.uniq( _.difference( c[k], _.flatten( [v] ) ) ),
                updatedAt: time
              } }
            } );
          }
        } );
      } );
      return Object.assign( { }, state, { obsCards: modified,
        selectedObsCards: _.pick( modified, _.keys( state.selectedObsCards ) )
      } );
    }

    case types.SELECT_OBS_CARDS: {
      let modified = Object.assign( { }, state.obsCards );
      for ( const k in modified ) {
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
      }
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
      _.each( modified, c => (
        modified = update( modified, {
          [c.id]: { $merge: { selected: true } }
        } )
      ) );
      return Object.assign( { }, state, { obsCards: modified,
        selectedObsCards: modified
      } );
    }

    case types.REMOVE_OBS_CARD: {
      const cards = Object.assign( { }, state.obsCards );
      const ids = Object.assign( { }, state.selectedIDs );
      delete cards[action.obsCard.id];
      delete ids[action.obsCard.id];
      return Object.assign( { }, state, { obsCards: cards, selectedIDs: ids } );
    }

    case types.REMOVE_FILE: {
      let updatedState = Object.assign( { }, state );
      const card = updatedState.obsCards[updatedState.files[action.file.id].cardID];
      const time = new Date( ).getTime( );
      // bump updatedAt for this file's card
      if ( card ) {
        updatedState = update( updatedState, { obsCards: {
          [card.id]: { $merge: { updatedAt: time, galleryIndex: 1 } }
        } } );
      }
      delete updatedState.files[action.file.id];
      // reset all card file associations
      _.each( updatedState.obsCards, ( obsCard, id ) => {
        updatedState.obsCards[id].files = _.pickBy( updatedState.files, f =>
          f.cardID === obsCard.id
        );
      } );
      return Object.assign( { }, state, {
        obsCards: updatedState.obsCards, files: updatedState.files } );
    }

    case types.REMOVE_SELECTED: {
      const modified = Object.assign( { }, state.obsCards );
      _.each( state.selectedObsCards, ( v, id ) => ( delete modified[id] ) );
      return Object.assign( { }, state, { obsCards: modified,
        selectedObsCards: { }
      } );
    }

    case types.CREATE_BLANK_OBS_CARD: {
      const obsCard = new ObsCard( );
      return update( state, { obsCards: {
        [obsCard.id]: { $set: obsCard }
      } } );
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
