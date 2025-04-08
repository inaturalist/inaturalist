import _ from "lodash";
import {
  SHOW_CURRENT_OBSERVATION,
  HIDE_CURRENT_OBSERVATION,
  RECEIVE_CURRENT_OBSERVATION,
  ADD_COMMENT,
  ADD_IDENTIFICATION,
  LOADING_DISCUSSION_ITEM,
  STOP_LOADING_DISCUSSION_ITEM,
  RECEIVE_OBSERVATIONS,
  UPDATE_CURRENT_OBSERVATION,
  AGREEING_WITH_OBSERVATION,
  STOP_AGREEING_WITH_OBSERVATION
} from "../actions";

const updateLoadingForItemInObs = ( item, observation, isLoading ) => {
  const obs = _.cloneDeep( observation );
  let existingItem;
  if ( item.className === "Identification" ) {
    existingItem = _.find(
      obs.identifications,
      i => i.id === item.id || ( item.uuid && item.uuid === i.uuid )
    );
  } else {
    existingItem = _.find(
      obs.comments,
      i => i.id === item.id || ( item.uuid && item.uuid === i.uuid )
    );
  }
  if ( existingItem ) {
    existingItem.loading = isLoading;
  }
  return obs;
};

const currentObservationReducer = ( state = { tab: "info" }, action ) => {
  switch ( action.type ) {
    case SHOW_CURRENT_OBSERVATION:
      return Object.assign( {}, state, {
        visible: true,
        observation: action.observation,
        commentFormVisible: false,
        identificationFormVisible: false,
        captiveByCurrentUser: action.observation.captiveByCurrentUser,
        reviewedByCurrentUser: action.observation.reviewedByCurrentUser,
        imagesCurrentIndex: 0
      } );
    case HIDE_CURRENT_OBSERVATION:
      return Object.assign( {}, state, {
        visible: false
      } );
    case RECEIVE_CURRENT_OBSERVATION: {
      const obs = _.cloneDeep( action.observation );
      obs.captiveByCurrentUser = action.captiveByCurrentUser;
      obs.reviewedByCurrentUser = action.reviewedByCurrentUser;
      return Object.assign( {}, state, {
        observation: obs,
        captiveByCurrentUser: action.captiveByCurrentUser,
        reviewedByCurrentUser: action.reviewedByCurrentUser,
        loadingDiscussionItem: false,
        currentUserIdentification: action.currentUserIdentification,
        keyboardShortcutsShown: false
      } );
    }
    case UPDATE_CURRENT_OBSERVATION:
      // If for some reason we're reducing an attempt to update the current
      // observation but the request was made when the current observation
      // was *different*, just bail. Potential workaround for
      // https://github.com/inaturalist/inaturalist/issues/4478 which I can't
      // replicate. ~~~~kueda 20250304
      if ( action.observation_id && action.observation_id !== state.observation.id ) {
        return state;
      }
      return Object.assign( {}, state, {
        observation: Object.assign( {}, state.observation, action.updates )
      }, action.updates );
    case ADD_COMMENT:
      return Object.assign( {}, state, {
        commentFormVisible: true,
        identificationFormVisible: false
      } );
    case ADD_IDENTIFICATION:
      return Object.assign( {}, state, {
        identificationFormVisible: true,
        commentFormVisible: false
      } );
    case LOADING_DISCUSSION_ITEM: {
      return Object.assign( {}, state, {
        observation:
          action.item
            ? updateLoadingForItemInObs( action.item, state.observation, true )
            : state.observation,
        loadingDiscussionItem: true,
        identificationFormVisible: false,
        commentFormVisible: false
      } );
    }
    case STOP_LOADING_DISCUSSION_ITEM: {
      return Object.assign( {}, state, {
        observation:
          action.item
            ? updateLoadingForItemInObs( action.item, state.observation, false )
            : state.observation,
        loadingDiscussionItem: false,
        identificationFormVisible: false,
        commentFormVisible: false
      } );
    }
    case AGREEING_WITH_OBSERVATION:
      return Object.assign( {}, state, {
        agreeingWithObservation: true
      } );
    case STOP_AGREEING_WITH_OBSERVATION:
      return Object.assign( {}, state, {
        agreeingWithObservation: false
      } );
    case RECEIVE_OBSERVATIONS:
      return Object.assign( { }, state, { observation: null } );
    default:
      return state;
  }
};

export default currentObservationReducer;
