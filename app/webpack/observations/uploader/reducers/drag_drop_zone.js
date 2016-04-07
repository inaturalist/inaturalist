import * as types from "../constants/constants";
import update from "react-addons-update";
import ObsCard from "../models/obs_card";

const defaultState = {
  obsCards: { },
  numberOfUploads: 0,
  maximumNumberOfUploads: 2,
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

    case types.UPDATE_SELECTED_OBS_CARDS: {
      let modified = Object.assign( { }, state.obsCards );
      for ( const id in state.selectedObsCards ) {
        modified = update( modified, {
          [id]: { $merge: action.attrs }
        } );
      }
      return Object.assign( { }, state, { obsCards: modified,
        selectedObsCards: _.pick( modified, ( v, k ) => ( state.selectedObsCards[k] ) )
      } );
    }

    case types.SELECT_OBS_CARDS: {
      const modified = Object.assign( { }, state.obsCards );
      for ( const k in modified ) {
        if ( action.ids[modified[k].id] ) {
          modified[k].selected = true;
        } else {
          modified[k].selected = false;
        }
      }
      return Object.assign( { }, state, { obsCards: modified,
        selectedObsCards: _.pick( modified, ( v, k ) => ( action.ids[k] ) )
        } );
    }

    case types.REMOVE_OBS_CARD: {
      const cards = Object.assign( { }, state.obsCards );
      const ids = Object.assign( { }, state.selectedIDs );
      delete cards[action.obsCard.id];
      delete cards[action.obsCard.id];
      delete ids[action.obsCard.id];
      return Object.assign( { }, state, { obsCards: cards, selectedIDs: ids } );
    }

    case types.SUBMIT_OBSERVATIONS: {
      return update( state, {
        uploaderStatus: { $set: "uploading" }
      } );
    }

    case types.CREATE_BLANK_OBS_CARD: {
      const afterAdd = Object.assign( { }, state.obsCards );
      const blankObsCard = new ObsCard( { id: new Date( ).getTime( ) } );
      afterAdd[blankObsCard.id] = blankObsCard;
      return Object.assign( { }, state, { obsCards: afterAdd } );
    }
    default:
      return state;
  }
};

export default dragDropZone;
