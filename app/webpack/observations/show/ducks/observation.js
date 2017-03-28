import _ from "lodash";
import inatjs from "inaturalistjs";
import moment from "moment";
import { fetchObservationPlaces, setObservationPlaces } from "./observation_places";
import { fetchControlledTerms, setControlledTerms } from "./controlled_terms";
import { fetchMoreFromThisUser, fetchNearby, fetchMoreFromClade,
  setMoreFromThisUser, setNearby, setMoreFromClade } from "./other_observations";
import { fetchQualityMetrics, setQualityMetrics } from "./quality_metrics";
import { fetchSubscriptions, setSubscriptions } from "./subscriptions";
import { fetchIdentifiers, setIdentifiers } from "./identifications";
import { setFlaggingModalState } from "./flagging_modal";
import { setConfirmModalState, handleAPIError } from "./confirm_modal";
import { updateSession } from "./users";

const SET_OBSERVATION = "obs-show/observation/SET_OBSERVATION";
const SET_ATTRIBUTES = "obs-show/observation/SET_ATTRIBUTES";
let lastAction;

function hasObsAndLoggedIn( state ) {
  return ( state.config && state.config.currentUser && state.observation );
}

export default function reducer( state = { }, action ) {
  switch ( action.type ) {
    case SET_OBSERVATION:
      return action.observation;
    case SET_ATTRIBUTES:
      return Object.assign( { }, state, action.attributes );
    default:
  }
  return state;
}

export function setObservation( observation ) {
  return {
    type: SET_OBSERVATION,
    observation
  };
}

export function setAttributes( attributes ) {
  return {
    type: SET_ATTRIBUTES,
    attributes
  };
}

export function getActionTime( ) {
  const currentTime = new Date( ).getTime( );
  lastAction = currentTime;
  return currentTime;
}

export function resetStates( ) {
  return dispatch => {
    dispatch( setIdentifiers( [] ) );
    dispatch( setObservationPlaces( [] ) );
    dispatch( setControlledTerms( [] ) );
    dispatch( setQualityMetrics( [] ) );
    dispatch( setMoreFromThisUser( [] ) );
    dispatch( setNearby( [] ) );
    dispatch( setMoreFromClade( [] ) );
    dispatch( setSubscriptions( [] ) );
  };
}

export function fetchTaxonSummary( ) {
  return ( dispatch, getState ) => {
    const observation = getState( ).observation;
    if ( !observation || !observation.taxon ) { return null; }
    const params = { id: observation.id };
    return inatjs.observations.taxonSummary( params ).then( response => {
      dispatch( setAttributes( { taxon:
        Object.assign( { }, observation.taxon, { taxon_summary: response } ) } ) );
    } );
  };
}

export function fetchObservation( id, options = { } ) {
  return ( dispatch, getState ) => {
    const s = getState( );
    const params = {
      preferred_place_id: s.config.preferredPlace ? s.config.preferredPlace.id : null,
      locale: I18n.locale
    };
    const originalObservation = s.observation;
    return inatjs.observations.fetch( id, params ).then( response => {
      const observation = response.results[0];
      const taxonUpdated = ( originalObservation &&
        originalObservation.id === observation.id &&
        ( ( !originalObservation.taxon && observation.taxon ) ||
          ( originalObservation.taxon && !observation.taxon ) ||
          ( originalObservation.taxon.id !== observation.taxon.id ) ) );
      dispatch( setObservation( observation ) );
      if ( options.resetStates ) {
        dispatch( resetStates( ) );
      } else if ( taxonUpdated ) {
        dispatch( setIdentifiers( [] ) );
        dispatch( setMoreFromClade( [] ) );
      }
      dispatch( fetchTaxonSummary( ) );
      if ( options.fetchControlledTerms ) { dispatch( fetchControlledTerms( ) ); }
      if ( options.fetchQualityMetrics ) { dispatch( fetchQualityMetrics( ) ); }
      if ( options.fetchSubscriptions ) { dispatch( fetchSubscriptions( ) ); }
      if ( options.fetchPlaces ) { dispatch( fetchObservationPlaces( ) ); }
      setTimeout( ( ) => {
        if ( options.fetchOtherObservations ) {
          dispatch( fetchMoreFromThisUser( ) );
          dispatch( fetchNearby( ) );
        }
        if ( options.fetchOtherObservations || taxonUpdated ) {
          dispatch( fetchMoreFromClade( ) );
        }
        if ( ( options.fetchIdentifiers || taxonUpdated ) &&
             observation.taxon && observation.taxon.rank_level <= 50 ) {
          dispatch( fetchIdentifiers( { taxon_id: observation.taxon.id, per_page: 10 } ) );
        }
      }, taxonUpdated ? 1 : 2000 );
      if ( s.flaggingModal && s.flaggingModal.item && s.flaggingModal.show ) {
        // TODO: put item type in flaggingModal state
        const item = s.flaggingModal.item;
        let newItem;
        if ( id === item.id ) { newItem = observation; }
        newItem = newItem || _.find( observation.comments, c => c.id === item.id );
        newItem = newItem || _.find( observation.identifications, c => c.id === item.id );
        if ( newItem ) { dispatch( setFlaggingModalState( "item", newItem ) ); }
      }
      if ( options.callback ) {
        options.callback( );
      }
    } );
  };
}

export function afterAPICall( id, options ) {
  return ( dispatch, getState ) => {
    const state = getState( );
    if ( !state.observation ) { return; }
    if ( options.error ) {
      dispatch( handleAPIError( options.error, I18n.t( "failed_to_save_record" ) ) );
    }
    if ( options.actionTime && lastAction !== options.actionTime ) { return; }
    dispatch( fetchObservation( id, options ) );
  };
}

export function updateObservation( attributes ) {
  return ( dispatch, getState ) => {
    const state = getState( );
    if ( !hasObsAndLoggedIn( state ) ) { return; }
    const payload = {
      id: state.observation.id,
      ignore_photos: true,
      observation: Object.assign( { }, { id: state.observation.id }, attributes )
    };
    const actionTime = getActionTime( );
    inatjs.observations.update( payload ).then( ( ) => {
      dispatch( afterAPICall( state.observation.id, { actionTime } ) );
    } ).catch( e => {
      dispatch( afterAPICall( state.observation.id, { actionTime, error: e } ) );
    } );
  };
}

export function addTag( tag ) {
  return ( dispatch, getState ) => {
    const state = getState( );
    if ( !tag || !hasObsAndLoggedIn( state ) ) { return; }
    if ( _.find( state.observation.tags, t => (
      _.lowerCase( t.tag || t ) === _.lowerCase( tag ) ) ) ) { return; }
    dispatch( setAttributes( { tags: state.observation.tags.concat( [{
      tag,
      api_status: "saving"
    }] ) } ) );

    let newTagList = tag;
    const tags = state.observation.tags;
    if ( !_.isEmpty( tags ) ) {
      const currentTags = _.filter( tags, t => ( t.api_status !== "deleting" ) );
      const currentTagList = _.map( currentTags, t => ( t.tag || t ) ).join( ", " );
      newTagList = `${newTagList}, ${currentTagList}`;
    }
    dispatch( updateObservation( { tag_list: newTagList } ) );
  };
}

export function removeTag( tag ) {
  return ( dispatch, getState ) => {
    const state = getState( );
    if ( !tag || !hasObsAndLoggedIn( state ) ) { return; }
    const newTags = _.map( state.observation.tags, t => (
      t === tag ? { tag: t, api_status: "deleting" } : t
    ) );
    dispatch( setAttributes( { tags: newTags } ) );

    const currentTags = _.filter( state.observation.tags, t => ( t.api_status !== "deleting" ) );
    const newTagList = _.map( _.without( currentTags, tag ), t => ( t.tag || t ) ).join( ", " );
    dispatch( updateObservation( { tag_list: newTagList } ) );
  };
}

export function addComment( body ) {
  return ( dispatch, getState ) => {
    const state = getState( );
    if ( !hasObsAndLoggedIn( state ) ) { return; }
    dispatch( setAttributes( { comments: state.observation.comments.concat( [{
      created_at: moment( ).format( ),
      user: state.config.currentUser,
      body,
      api_status: "saving"
    }] ) } ) );

    const payload = {
      parent_type: "Observation",
      parent_id: state.observation.id,
      body
    };
    const actionTime = getActionTime( );
    inatjs.comments.create( payload ).then( ( ) => {
      dispatch( afterAPICall( state.observation.id, { actionTime } ) );
    } ).catch( e => {
      dispatch( afterAPICall( state.observation.id, { actionTime, error: e } ) );
    } );
  };
}

export function deleteComment( id ) {
  return ( dispatch, getState ) => {
    const state = getState( );
    if ( !hasObsAndLoggedIn( state ) ) { return; }
    const newComments = _.map( state.observation.comments, c => (
      c.id === id ?
        Object.assign( { }, c, { api_status: "deleting" } ) : c
    ) );
    dispatch( setAttributes( { comments: newComments } ) );

    const payload = { id };
    const actionTime = getActionTime( );
    inatjs.comments.delete( payload ).then( ( ) => {
      dispatch( afterAPICall( state.observation.id, { actionTime } ) );
    } ).catch( e => {
      dispatch( afterAPICall( state.observation.id, { actionTime, error: e } ) );
    } );
  };
}


export function confirmDeleteComment( id ) {
  return ( dispatch ) => {
    dispatch( setConfirmModalState( {
      show: true,
      message: "Are you sure you want to delete this comment?",
      confirmText: "Yes",
      onConfirm: ( ) => {
        dispatch( deleteComment( id ) );
      }
    } ) );
  };
}

export function doAddID( taxon, body, confirmForm ) {
  return ( dispatch, getState ) => {
    const state = getState( );
    if ( !hasObsAndLoggedIn( state ) ) { return; }
    if ( confirmForm && confirmForm.silenceCoarse ) {
      dispatch( updateSession( { prefers_skip_coarer_id_modal: true } ) );
    }
    const newIdentifications = _.map( state.observation.identifications, i => (
      i.user.id === state.config.currentUser.id ?
        Object.assign( { }, i, { current: false } ) : i
    ) );
    dispatch( setAttributes( { identifications: newIdentifications.concat( [{
      created_at: moment( ).format( ),
      user: state.config.currentUser,
      body,
      taxon,
      current: true,
      api_status: "saving"
    }] ) } ) );

    const payload = {
      observation_id: state.observation.id,
      taxon_id: taxon.id,
      body
    };
    const actionTime = getActionTime( );
    inatjs.identifications.create( payload ).then( ( ) => {
      dispatch( afterAPICall( state.observation.id, { actionTime } ) );
    } ).catch( e => {
      dispatch( afterAPICall( state.observation.id, { actionTime, error: e } ) );
    } );
  };
}

export function addID( taxon, body ) {
  return ( dispatch, getState ) => {
    const state = getState( );
    if ( !hasObsAndLoggedIn( state ) ) { return; }
    const observation = state.observation;
    const config = state.config;
    const userPrefersSkip = config && config.currentUser &&
      config.currentUser.prefers_skip_coarer_id_modal;
    if ( !userPrefersSkip && observation.taxon && taxon.id !== observation.taxon.id &&
         _.includes( observation.taxon.ancestor_ids, taxon.id ) ) {
      dispatch( setConfirmModalState( {
        show: true,
        type: "coarserID",
        idTaxon: taxon,
        existingTaxon: observation.taxon,
        confirmText: "Proceed",
        onConfirm: ( confirmForm ) => {
          dispatch( doAddID( taxon, body, confirmForm ) );
        }
      } ) );
    } else {
      dispatch( doAddID( taxon, body ) );
    }
  };
}

export function deleteID( id ) {
  return ( dispatch, getState ) => {
    const state = getState( );
    if ( !hasObsAndLoggedIn( state ) ) { return; }
    const newIdentifications = _.map( state.observation.identifications, i => (
      i.id === id ?
        Object.assign( { }, i, { current: false, api_status: "deleting" } ) : i
    ) );
    dispatch( setAttributes( { identifications: newIdentifications } ) );
    const actionTime = getActionTime( );
    inatjs.identifications.delete( { id } ).then( ( ) => {
      dispatch( afterAPICall( state.observation.id, { actionTime } ) );
    } ).catch( e => {
      dispatch( afterAPICall( state.observation.id, { actionTime, error: e } ) );
    } );
  };
}

export function restoreID( id ) {
  return ( dispatch, getState ) => {
    const state = getState( );
    if ( !hasObsAndLoggedIn( state ) ) { return; }
    const payload = {
      id,
      current: true
    };
    const actionTime = getActionTime( );
    inatjs.identifications.update( payload ).then( ( ) => {
      dispatch( afterAPICall( state.observation.id, { actionTime } ) );
    } ).catch( e => {
      dispatch( afterAPICall( state.observation.id, { actionTime, error: e } ) );
    } );
  };
}

export function vote( scope, params = { } ) {
  return ( dispatch, getState ) => {
    const state = getState( );
    const payload = Object.assign( { }, { id: state.observation.id }, params );
    if ( scope ) {
      payload.scope = scope;
      const newVotes = state.observation.votes.concat( [{
        vote_flag: ( params.vote === "yes" ),
        vote_scope: payload.scope,
        user: state.config.currentUser,
        temporary: true,
        api_status: "saving"
      }] );
      dispatch( setAttributes( { votes: newVotes } ) );
    }
    const actionTime = getActionTime( );
    inatjs.observations.fave( payload ).then( ( ) => {
      dispatch( afterAPICall( state.observation.id, { actionTime } ) );
    } ).catch( e => {
      dispatch( afterAPICall( state.observation.id, { actionTime, error: e } ) );
    } );
  };
}

export function unvote( scope ) {
  return ( dispatch, getState ) => {
    const state = getState( );
    const payload = { id: state.observation.id };
    if ( scope ) {
      payload.scope = scope;
      const newVotes = _.map( state.observation.votes, v => (
        ( v.user.id === state.config.currentUser.id && v.vote_scope === scope ) ?
          Object.assign( { }, v, { api_status: "deleting" } ) : v
      ) );
      dispatch( setAttributes( { votes: newVotes } ) );
    }
    const actionTime = getActionTime( );
    inatjs.observations.unfave( payload ).then( ( ) => {
      dispatch( afterAPICall( state.observation.id, { actionTime } ) );
    } ).catch( e => {
      dispatch( afterAPICall( state.observation.id, { actionTime, error: e } ) );
    } );
  };
}

export function fave( ) {
  return ( dispatch, getState ) => {
    const state = getState( );
    if ( !hasObsAndLoggedIn( state ) ) { return; }
    const newFaves = state.observation.faves.concat( [{
      votable_id: state.observation.id,
      user: state.config.currentUser,
      temporary: true
    }] );
    dispatch( setAttributes( { faves: newFaves } ) );
    dispatch( vote( ) );
  };
}

export function unfave( ) {
  return ( dispatch, getState ) => {
    const state = getState( );
    if ( !hasObsAndLoggedIn( state ) ) { return; }
    const newFaves = state.observation.faves.filter( f => (
      f.user.id !== state.config.currentUser.id
    ) );
    dispatch( setAttributes( { faves: newFaves } ) );
    dispatch( unvote( ) );
  };
}

export function followUser( ) {
  return ( dispatch, getState ) => {
    const state = getState( );
    if ( !state.config || !state.config.currentUser ||
         !state.observation || state.config.currentUser.id === state.observation.user.id ) {
      return;
    }
    const newSubscriptions = state.subscriptions.concat( [{
      resource_type: "User",
      resource_id: state.observation.user.id,
      user_id: state.config.currentUser.id,
      api_status: "saving"
    }] );
    dispatch( setSubscriptions( newSubscriptions ) );
    const payload = { id: state.config.currentUser.id, friend_id: state.observation.user.id };
    inatjs.users.update( payload ).then( ( ) => {
      dispatch( fetchSubscriptions( ) );
    } ).catch( e => {
      dispatch( handleAPIError( e, I18n.t( "failed_to_save_record" ) ) );
      dispatch( fetchSubscriptions( ) );
    } );
  };
}

export function unfollowUser( ) {
  return ( dispatch, getState ) => {
    const state = getState( );
    if ( !state.config || !state.config.currentUser ||
         !state.observation || state.config.currentUser.id === state.observation.user.id ) {
      return;
    }
    const newSubscriptions = _.map( state.subscriptions, s => (
      s.resource_type === "User" ?
        Object.assign( { }, s, { api_status: "deleting" } ) : s
    ) );
    dispatch( setSubscriptions( newSubscriptions ) );

    const payload = {
      id: state.config.currentUser.id,
      remove_friend_id: state.observation.user.id
    };
    inatjs.users.update( payload ).then( ( ) => {
      dispatch( fetchSubscriptions( ) );
    } ).catch( e => {
      dispatch( handleAPIError( e, I18n.t( "failed_to_save_record" ) ) );
      dispatch( fetchSubscriptions( ) );
    } );
  };
}

export function subscribe( ) {
  return ( dispatch, getState ) => {
    const state = getState( );
    if ( !state.config || !state.config.currentUser ||
         !state.observation || state.config.currentUser.id === state.observation.user.id ) {
      return;
    }
    const obsSubscription = _.find( state.subscriptions, s => (
      s.resource_type === "Observation" ) );
    if ( obsSubscription ) {
      const newSubscriptions = _.map( state.subscriptions, s => (
        s.resource_type === "Observation" ?
          Object.assign( { }, s, { api_status: "deleting" } ) : s
      ) );
      dispatch( setSubscriptions( newSubscriptions ) );
    } else {
      const newSubscriptions = state.subscriptions.concat( [{
        resource_type: "Observation",
        resource_id: state.observation.id,
        user_id: state.config.currentUser.id,
        api_status: "saving"
      }] );
      dispatch( setSubscriptions( newSubscriptions ) );
    }
    const payload = { id: state.observation.id };
    inatjs.observations.subscribe( payload ).then( ( ) => {
      dispatch( fetchSubscriptions( ) );
    } ).catch( e => {
      dispatch( handleAPIError( e, I18n.t( "failed_to_save_record" ) ) );
      dispatch( fetchSubscriptions( ) );
    } );
  };
}

export function addAnnotation( controlledAttribute, controlledValue ) {
  return ( dispatch, getState ) => {
    const state = getState( );
    if ( !hasObsAndLoggedIn( state ) ) { return; }
    console.log(state.observation.annotations);
    const newAnnotations = ( state.observation.annotations || [] ).concat( [{
      controlled_attribute: controlledAttribute,
      controlled_value: controlledValue,
      user: state.config.currentUser,
      api_status: "saving"
    }] );
    dispatch( setAttributes( { annotations: newAnnotations } ) );

    const payload = {
      resource_type: "Observation",
      resource_id: state.observation.id,
      controlled_attribute_id: controlledAttribute.id,
      controlled_value_id: controlledValue.id
    };
    const actionTime = getActionTime( );
    inatjs.annotations.create( payload ).then( ( ) => {
      dispatch( afterAPICall( state.observation.id, {
        actionTime, fetchQualityMetrics: true } ) );
    } ).catch( e => {
      dispatch( afterAPICall( state.observation.id, {
        actionTime, error: e, fetchQualityMetrics: true } ) );
    } );
  };
}

export function deleteAnnotation( id ) {
  return ( dispatch, getState ) => {
    const state = getState( );
    if ( !hasObsAndLoggedIn( state ) ) { return; }
    const newAnnotations = _.map( state.observation.annotations, a => (
      ( a.user.id === state.config.currentUser.id && a.uuid === id ) ?
        Object.assign( { }, a, { api_status: "deleting" } ) : a
    ) );
    dispatch( setAttributes( { annotations: newAnnotations } ) );

    const payload = { id };
    const actionTime = getActionTime( );
    inatjs.annotations.delete( payload ).then( ( ) => {
      dispatch( afterAPICall( state.observation.id, {
        actionTime, fetchQualityMetrics: true } ) );
    } ).catch( e => {
      dispatch( afterAPICall( state.observation.id, {
        actionTime, error: e, fetchQualityMetrics: true } ) );
    } );
  };
}

export function voteAnnotation( id, voteValue ) {
  return ( dispatch, getState ) => {
    const state = getState( );
    if ( !hasObsAndLoggedIn( state ) ) { return; }
    const newAnnotations = _.map( state.observation.annotations, a => (
      ( a.uuid === id ) ?
        Object.assign( { }, a, {
          api_status: "voting",
          votes: ( a.votes || [] ).concat( [{
            vote_flag: ( voteValue !== "bad" ),
            user: state.config.currentUser,
            api_status: "saving"
          }] )
        } ) : a
    ) );
    dispatch( setAttributes( { annotations: newAnnotations } ) );

    const payload = { id, vote: voteValue };
    const actionTime = getActionTime( );
    inatjs.annotations.vote( payload ).then( ( ) => {
      dispatch( afterAPICall( state.observation.id, {
        actionTime, fetchQualityMetrics: true } ) );
    } ).catch( e => {
      dispatch( afterAPICall( state.observation.id, {
        actionTime, error: e, fetchQualityMetrics: true } ) );
    } );
  };
}

export function unvoteAnnotation( id ) {
  return ( dispatch, getState ) => {
    const state = getState( );
    if ( !hasObsAndLoggedIn( state ) ) { return; }
    const newAnnotations = _.map( state.observation.annotations, a => (
      ( a.uuid === id ) ?
        Object.assign( { }, a, {
          api_status: "voting",
          votes: _.map( a.votes, v => (
            v.user.id === state.config.currentUser.id ?
              Object.assign( { }, v, { api_status: "deleting" } ) : v
          ) )
        } ) : a
    ) );
    dispatch( setAttributes( { annotations: newAnnotations } ) );

    const payload = { id };
    const actionTime = getActionTime( );
    inatjs.annotations.unvote( payload ).then( ( ) => {
      dispatch( afterAPICall( state.observation.id, {
        actionTime, fetchQualityMetrics: true } ) );
    } ).catch( e => {
      dispatch( afterAPICall( state.observation.id, {
        actionTime, error: e, fetchQualityMetrics: true } ) );
    } );
  };
}

export function voteMetric( metric, params = { } ) {
  if ( metric === "needs_id" ) {
    return vote( "needs_id", { vote: ( params.agree === "false" ) ? "no" : "yes" } );
  }
  return ( dispatch, getState ) => {
    const state = getState( );
    if ( !hasObsAndLoggedIn( state ) ) { return; }
    const newMetrics = state.qualityMetrics.concat( [{
      observation_id: state.observation.id,
      metric,
      agree: ( params.agree !== "false" ),
      created_at: moment( ).format( ),
      user: state.config.currentUser,
      api_status: "saving"
    }] );
    dispatch( setQualityMetrics( newMetrics ) );

    const payload = Object.assign( { }, { id: state.observation.id, metric }, params );
    const actionTime = getActionTime( );
    inatjs.observations.setQualityMetric( payload ).then( ( ) => {
      dispatch( afterAPICall( state.observation.id, {
        actionTime, fetchQualityMetrics: true } ) );
    } ).catch( e => {
      dispatch( afterAPICall( state.observation.id, {
        actionTime, error: e, fetchQualityMetrics: true } ) );
    } );
  };
}

export function unvoteMetric( metric ) {
  if ( metric === "needs_id" ) {
    return unvote( "needs_id" );
  }
  return ( dispatch, getState ) => {
    const state = getState( );
    if ( !hasObsAndLoggedIn( state ) ) { return; }
    const newMetrics = _.map( state.qualityMetrics, qm => (
      ( qm.user.id === state.config.currentUser.id && qm.metric === metric ) ?
        Object.assign( { }, qm, { api_status: "deleting" } ) : qm
    ) );
    dispatch( setQualityMetrics( newMetrics ) );

    const payload = { id: state.observation.id, metric };
    const actionTime = getActionTime( );
    inatjs.observations.deleteQualityMetric( payload ).then( ( ) => {
      dispatch( afterAPICall( state.observation.id, {
        actionTime, fetchQualityMetrics: true } ) );
    } ).catch( e => {
      dispatch( afterAPICall( state.observation.id, {
        actionTime, error: e, fetchQualityMetrics: true } ) );
    } );
  };
}

export function addToProject( project ) {
  return ( dispatch, getState ) => {
    const state = getState( );
    if ( !hasObsAndLoggedIn( state ) ) { return; }
    const newProjectObs = _.clone( state.observation.project_observations );
    newProjectObs.unshift( {
      project,
      user_id: state.config.currentUser.id,
      user: state.config.currentUser,
      temporary: true
    } );
    dispatch( setAttributes( { project_observations: newProjectObs } ) );

    const payload = { id: project.id, observation_id: state.observation.id };
    inatjs.projects.add( payload ).then( ( ) => {
      dispatch( fetchObservation( state.observation.id ) );
    } ).catch( e => {
      dispatch( handleAPIError( e, `Failed to add to project ${project.title}` ) );
      dispatch( fetchObservation( state.observation.id ) );
    } );
  };
}

export function removeFromProject( project ) {
  return ( dispatch, getState ) => {
    const state = getState( );
    if ( !hasObsAndLoggedIn( state ) ) { return; }
    const newProjectObs = state.observation.project_observations.filter( po => (
      po.project.id !== project.id
    ) );
    dispatch( setAttributes( { project_observations: newProjectObs } ) );

    const payload = { id: project.id, observation_id: state.observation.id };
    inatjs.projects.remove( payload ).then( ( ) => {
      dispatch( fetchObservation( state.observation.id ) );
    } ).catch( e => {
      dispatch( handleAPIError( e, I18n.t( "failed_to_save_record" ) ) );
      dispatch( fetchObservation( state.observation.id ) );
    } );
  };
}

export function confirmRemoveFromProject( project ) {
  return ( dispatch ) => {
    dispatch( setConfirmModalState( {
      show: true,
      message: `Are you sure you want to remove this observation from ${project.title}?`,
      confirmText: "Yes",
      onConfirm: ( ) => {
        dispatch( removeFromProject( project ) );
      }
    } ) );
  };
}

export function windowStateForObservation( observation ) {
  return {
    state: { observation: { id: observation.id } },
    title: "TODO: set the title",
    url: `/observations/${observation.id}`
  };
}

export function showNewObservation( observation, options ) {
  return dispatch => {
    dispatch( fetchObservation( observation.id, {
      resetStates: true,
      fetchPlaces: true,
      fetchControlledTerms: true,
      fetchQualityMetrics: true,
      fetchOtherObservations: true,
      fetchSubscriptions: true,
      fetchIdentifiers: true
    } ) ).then( ( ) => {
      window.scrollTo( 0, 0 );
      const s = windowStateForObservation( observation );
      if ( !( options && options.skipSetState ) ) {
        history.pushState( s.state, s.title, s.url );
      }
      document.title = s.title;
    } );
  };
}
