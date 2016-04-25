import _ from "lodash";
import * as types from "../constants/constants";
import update from "react-addons-update";
import ObsCard from "../models/obs_card";

const defaultState = {
  obsCards: { },
  numberOfUploads: 0,
  maximumNumberOfUploads: 3,
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

    case types.UPDATE_OBS_CARD: {
      if ( state.obsCards[action.obsCard.id] === undefined ) {
        return state;
      }
      return update( state, {
        obsCards: { [action.obsCard.id]: { $merge: action.attrs } }
      } );
    }

    case types.UPDATE_OBS_CARD_FILE: {
      if ( state.obsCards[action.obsCard.id] === undefined ||
           state.obsCards[action.obsCard.id].files[action.file.id] === undefined ) {
        return state;
      }
      return update( state, {
        obsCards: { [action.obsCard.id]: {
          files: { [action.file.id]: { $merge: action.attrs } }
        } }
      } );
    }

    case types.UPDATE_SELECTED_OBS_CARDS: {
      let modified = Object.assign( { }, state.obsCards );
      _.each( state.selectedObsCards, c => {
        modified = update( modified, {
          [c.id]: { $merge: action.attrs }
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
      return Object.assign( { }, state, { obsCards: modified,
        selectedObsCards: _.pick( modified, _.keys( action.ids ) )
      } );
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
