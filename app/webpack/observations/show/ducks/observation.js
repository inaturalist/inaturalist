import _ from "lodash";
import inatjs from "inaturalistjs";
import moment from "moment";
import { fetchObservationPlaces, setObservationPlaces } from "./observation_places";
import { fetchControlledTerms, setControlledTerms } from "./controlled_terms";
import { fetchMoreFromThisUser, fetchNearby, fetchMoreFromClade,
  setEarlierUserObservations, setLaterUserObservations, setNearby,
  setMoreFromClade } from "./other_observations";
import { fetchQualityMetrics, setQualityMetrics } from "./quality_metrics";
import { fetchSubscriptions, setSubscriptions } from "./subscriptions";
import { fetchIdentifiers, setIdentifiers } from "./identifications";
import { setFlaggingModalState } from "./flagging_modal";
import { setConfirmModalState, handleAPIError } from "./confirm_modal";
import { setProjectFieldsModalState } from "./project_fields_modal";
import { updateSession } from "./users";
import util from "../util";
import { showDisagreementAlert } from "../../shared/ducks/disagreement_alert";

const SET_OBSERVATION = "obs-show/observation/SET_OBSERVATION";
const SET_ATTRIBUTES = "obs-show/observation/SET_ATTRIBUTES";
let lastAction;

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

/* global SITE */
export function windowStateForObservation( observation ) {
  const observationState = {
    observation: {
      id: observation.id,
      observed_on: observation.observed_on,
      user: {
        login: observation.user.login
      }
    }
  };
  let title = `observed by ${observation.user.login}`;
  if ( observation.taxon ) {
    title = `${observation.taxon.preferred_common_name || observation.taxon.name} ${title}`;
    observationState.observation.taxon = {
      name: observation.taxon.name,
      preferred_common_name: observation.taxon.preferred_common_name
    };
  } else {
    title = `${I18n.t( "something" )} ${title}`;
  }
  if ( observation.observed_on ) {
    const date = moment( observation.observed_on ).format( "MMMM D, YYYY" );
    title = `${title} on ${date}`;
  }
  const windowState = {
    state: observationState,
    title: `${title} · ${SITE.name}`,
    url: `/observations/${observation.id}${window.location.search}`
  };
  return windowState;
}

export function getActionTime( ) {
  const currentTime = new Date( ).getTime( );
  lastAction = currentTime;
  return currentTime;
}

export function hasObsAndLoggedIn( state ) {
  return ( state && state.config && state.config.currentUser && state.observation );
}

export function userIsObserver( state ) {
  return ( hasObsAndLoggedIn( state ) &&
           state.config.currentUser.id === state.observation.user.id );
}

export function resetStates( ) {
  return dispatch => {
    dispatch( setObservation( { } ) );
    dispatch( setIdentifiers( [] ) );
    dispatch( setObservationPlaces( [] ) );
    dispatch( setControlledTerms( [] ) );
    dispatch( setQualityMetrics( [] ) );
    dispatch( setEarlierUserObservations( [] ) );
    dispatch( setLaterUserObservations( [] ) );
    dispatch( setNearby( [] ) );
    dispatch( setMoreFromClade( [] ) );
    dispatch( setSubscriptions( [] ) );
  };
}

export function fetchTaxonSummary( ) {
  return ( dispatch, getState ) => {
    const observation = getState( ).observation;
    if ( !observation || !observation.taxon ) { return null; }
    const params = { id: observation.id, ttl: -1 };
    return inatjs.observations.taxonSummary( params ).then( response => {
      dispatch( setAttributes( { taxon:
        Object.assign( { }, observation.taxon, { taxon_summary: response } ) } ) );
    } ).catch( e => console.log( e ) );
  };
}

export function renderObservation( observation, options = { } ) {
  return ( dispatch, getState ) => {
    if ( !observation || !observation.id ) {
      console.log( "observation not found" );
      return;
    }
    const s = getState( );
    const originalObservation = s.observation;
    const fetchAll = options.fetchAll;
    const taxonUpdated = ( originalObservation &&
      originalObservation.id === observation.id &&
      ( ( !originalObservation.taxon && observation.taxon ) ||
        ( originalObservation.taxon && !observation.taxon ) ||
        ( originalObservation.taxon && observation.taxon &&
          originalObservation.taxon.id !== observation.taxon.id ) ) );
    dispatch( setObservation( observation ) );
    if ( taxonUpdated ) {
      dispatch( setIdentifiers( [] ) );
      dispatch( setMoreFromClade( [] ) );
    }
    dispatch( fetchTaxonSummary( ) );
    if ( fetchAll || options.fetchControlledTerms ) { dispatch( fetchControlledTerms( ) ); }
    if ( fetchAll || options.fetchQualityMetrics ) { dispatch( fetchQualityMetrics( ) ); }
    if ( hasObsAndLoggedIn( s ) && ( fetchAll || options.fetchSubscriptions ) ) {
      dispatch( fetchSubscriptions( ) );
    }
    if ( fetchAll || options.fetchPlaces ) { dispatch( fetchObservationPlaces( ) ); }
    if ( fetchAll || options.replaceState ) {
      const ws = windowStateForObservation( observation );
      history.replaceState( ws.state, ws.title, ws.url );
    }
    // delay these requests for a short while, unless the taxon has changed
    // which is a user-initiated action that should have a quick re-render time
    setTimeout( ( ) => {
      if ( fetchAll || options.fetchOtherObservations ) {
        dispatch( fetchMoreFromThisUser( ) );
        dispatch( fetchNearby( ) );
      }
      if ( fetchAll || options.fetchOtherObservations || taxonUpdated ) {
        dispatch( fetchMoreFromClade( ) );
      }
      if ( ( fetchAll || options.fetchIdentifiers || taxonUpdated ) &&
           observation.taxon && observation.taxon.rank_level <= 50 ) {
        dispatch( fetchIdentifiers( {
          taxon_id: observation.taxon.id, quality_grade: "research", per_page: 10 } ) );
      }
      if ( fetchAll || options.fetchControlledTerms || taxonUpdated ) {
        dispatch( fetchControlledTerms( ) );
      }
    }, taxonUpdated ? 1 : 500 );
    if ( s.flaggingModal && s.flaggingModal.item && s.flaggingModal.show ) {
      const item = s.flaggingModal.item;
      let newItem;
      if ( observation.id === item.id ) { newItem = observation; }
      newItem = newItem || _.find( observation.comments, c => c.id === item.id );
      newItem = newItem || _.find( observation.identifications, c => c.id === item.id );
      if ( newItem ) { dispatch( setFlaggingModalState( { item: newItem } ) ); }
    }
    if ( options.callback ) {
      options.callback( );
    }
  };
}

export function fetchObservation( id, options = { } ) {
  return ( dispatch, getState ) => {
    const s = getState( );
    const params = {
      preferred_place_id: s.config.preferredPlace ? s.config.preferredPlace.id : null,
      locale: I18n.locale,
      ttl: -1
    };
    return inatjs.observations.fetch( id, params ).then( response => {
      dispatch( renderObservation( response.results[0], options ) );
    } ).catch( e => console.log( e ) );
  };
}

export function afterAPICall( options = { } ) {
  return ( dispatch, getState ) => {
    const state = getState( );
    if ( options.error ) {
      dispatch( handleAPIError( options.error,
        options.errorMessage || I18n.t( "failed_to_save_record" ) ) );
    }
    if ( options.callback ) {
      options.callback( );
    } else {
      if ( options.actionTime && lastAction !== options.actionTime ) { return; }
      if ( state.observation ) {
        dispatch( fetchObservation( state.observation.id, options ) );
      }
    }
  };
}

export function callAPI( method, payload, options = { } ) {
  return dispatch => {
    const opts = Object.assign( { }, options );
    // only need to keep track of the times of non-custom callbacks
    if ( !options.callback ) {
      opts.actionTime = getActionTime( );
    }
    method( payload ).then( ( ) => {
      dispatch( afterAPICall( opts ) );
    } ).catch( e => {
      opts.error = e;
      dispatch( afterAPICall( opts ) );
    } );
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
    dispatch( callAPI( inatjs.observations.update, payload ) );
  };
}

export function deleteObservation( ) {
  return ( dispatch, getState ) => {
    const state = getState( );
    if ( !userIsObserver( state ) ) { return; }
    dispatch( setConfirmModalState( {
      show: true,
      message: I18n.t( "you_sure_delete_this_observation" ),
      confirmText: I18n.t( "yes" ),
      onConfirm: ( ) => {
        const csrfParam = $( "meta[name=csrf-param]" ).attr( "content" );
        const csrfToken = $( "meta[name=csrf-token]" ).attr( "content" );
        const deleteForm = $( "<form>", {
          action: `/observations/${state.observation.id}`,
          method: "post"
        } );
        $( "<input>" ).attr( {
          type: "hidden",
          name: csrfParam,
          value: csrfToken
        } ).appendTo( deleteForm );
        $( "<input>" ).attr( {
          type: "hidden",
          name: "_method",
          value: "delete"
        } ).appendTo( deleteForm );
        deleteForm.appendTo( "body" ).submit( );
      }
    } ) );
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

export function review( ) {
  return ( dispatch, getState ) => {
    const state = getState( );
    if ( !hasObsAndLoggedIn( state ) ) { return; }
    dispatch( setAttributes( { reviewed_by: state.observation.reviewed_by.concat( [
      state.config.currentUser.id
    ] ) } ) );

    const payload = { id: state.observation.id };
    dispatch( callAPI( inatjs.observations.review, payload ) );
  };
}

export function unreview( ) {
  return ( dispatch, getState ) => {
    const state = getState( );
    if ( !hasObsAndLoggedIn( state ) ) { return; }
    const newReviewedBy = _.without( state.observation.reviewed_by, state.config.currentUser.id );
    dispatch( setAttributes( { reviewed_by: newReviewedBy } ) );

    const payload = { id: state.observation.id };
    dispatch( callAPI( inatjs.observations.unreview, payload ) );
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
    dispatch( callAPI( inatjs.comments.create, payload ) );
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
    dispatch( callAPI( inatjs.comments.delete, { id } ) );
  };
}


export function confirmDeleteComment( id ) {
  return ( dispatch ) => {
    dispatch( setConfirmModalState( {
      show: true,
      message: I18n.t( "you_sure_delete_comment?" ),
      confirmText: "Yes",
      onConfirm: ( ) => {
        dispatch( deleteComment( id ) );
      }
    } ) );
  };
}

export function doAddID( taxon, confirmForm, options = { } ) {
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
      body: options.body,
      agreedTo: options.agreedTo,
      disagreement: options.disagreement,
      taxon,
      current: true,
      api_status: "saving"
    }] ) } ) );

    const payload = {
      observation_id: state.observation.id,
      taxon_id: taxon.id,
      body: options.body,
      vision: !!taxon.isVisionResult,
      disagreement: options.disagreement
    };
    dispatch( callAPI( inatjs.identifications.create, payload ) );
  };
}

export function addID( taxon, options = { } ) {
  return ( dispatch, getState ) => {
    const state = getState( );
    if ( !hasObsAndLoggedIn( state ) ) { return; }
    const o = state.observation;
    let observationTaxon = o.taxon;
    if ( o.preferences.prefers_community_taxon === false || o.user.preferences.prefers_community_taxa === false ) {
      observationTaxon = o.community_taxon || o.taxon;
    }
    if (
      observationTaxon && taxon.id !== observationTaxon.id &&
      _.includes( observationTaxon.ancestor_ids, taxon.id )
    ) {
      dispatch( showDisagreementAlert( {
        onDisagree: ( ) => {
          dispatch( doAddID( taxon, { }, Object.assign( { disagreement: true }, options ) ) );
        },
        onBestGuess: ( ) => {
          dispatch( doAddID( taxon, { disagreement: false }, Object.assign( { disagreement: false }, options ) ) );
        },
        oldTaxon: observationTaxon,
        newTaxon: taxon
      } ) );
    } else {
      dispatch( doAddID( taxon, null, options ) );
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
    dispatch( callAPI( inatjs.identifications.delete, { id } ) );
  };
}

export function restoreID( id ) {
  return ( dispatch, getState ) => {
    const state = getState( );
    if ( !hasObsAndLoggedIn( state ) ) { return; }
    const newIdentifications = _.map( state.observation.identifications, i => (
      i.id === id ?
        Object.assign( { }, i, { current: true, api_status: "saving" } ) : i
    ) );
    dispatch( setAttributes( { identifications: newIdentifications } ) );
    dispatch( callAPI( inatjs.identifications.update, { id, current: true } ) );
  };
}

export function vote( scope, params = { } ) {
  return ( dispatch, getState ) => {
    const state = getState( );
    if ( !hasObsAndLoggedIn( state ) ) { return; }
    const payload = Object.assign( { }, { id: state.observation.id }, params );
    if ( scope ) {
      payload.scope = scope;
      const newVotes = _.filter( state.observation.votes, v => (
        !( v.user.id === state.config.currentUser.id && v.vote_scope === scope ) ) ).concat( [{
          vote_flag: ( params.vote === "yes" ),
          vote_scope: payload.scope,
          user: state.config.currentUser,
          api_status: "saving"
        }] );
      dispatch( setAttributes( { votes: newVotes } ) );
    }
    dispatch( callAPI( inatjs.observations.fave, payload ) );
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
    dispatch( callAPI( inatjs.observations.unfave, payload ) );
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
    if ( !hasObsAndLoggedIn( state ) ) { return; }
    if ( userIsObserver( state ) ) { return; }
    const newSubscriptions = state.subscriptions.concat( [{
      resource_type: "User",
      resource_id: state.observation.user.id,
      user_id: state.config.currentUser.id,
      api_status: "saving"
    }] );
    dispatch( setSubscriptions( newSubscriptions ) );
    const payload = { id: state.config.currentUser.id, friend_id: state.observation.user.id };
    dispatch( callAPI( inatjs.users.update, payload, { callback: ( ) => {
      dispatch( fetchSubscriptions( ) );
    } } ) );
  };
}

export function unfollowUser( ) {
  return ( dispatch, getState ) => {
    const state = getState( );
    if ( !hasObsAndLoggedIn( state ) ) { return; }
    if ( userIsObserver( state ) ) { return; }
    const newSubscriptions = _.map( state.subscriptions, s => (
      s.resource_type === "User" ?
        Object.assign( { }, s, { api_status: "deleting" } ) : s
    ) );
    dispatch( setSubscriptions( newSubscriptions ) );

    const payload = {
      id: state.config.currentUser.id,
      remove_friend_id: state.observation.user.id
    };
    dispatch( callAPI( inatjs.users.update, payload, { callback: ( ) => {
      dispatch( fetchSubscriptions( ) );
    } } ) );
  };
}

export function subscribe( ) {
  return ( dispatch, getState ) => {
    const state = getState( );
    if ( !hasObsAndLoggedIn( state ) ) { return; }
    if ( userIsObserver( state ) ) { return; }
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
    dispatch( callAPI( inatjs.observations.subscribe, payload, { callback: ( ) => {
      dispatch( fetchSubscriptions( ) );
    } } ) );
  };
}

export function addAnnotation( controlledAttribute, controlledValue ) {
  return ( dispatch, getState ) => {
    const state = getState( );
    if ( !hasObsAndLoggedIn( state ) ) { return; }
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
    dispatch( callAPI( inatjs.annotations.create, payload ) );
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
    dispatch( callAPI( inatjs.annotations.delete, { id } ) );
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
    dispatch( callAPI( inatjs.annotations.vote, { id, vote: voteValue } ) );
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
    dispatch( callAPI( inatjs.annotations.unvote, { id } ) );
  };
}

export function voteMetric( metric, params = { } ) {
  if ( metric === "needs_id" ) {
    return vote( "needs_id", { vote: ( params.agree === "false" ) ? "no" : "yes" } );
  }
  return ( dispatch, getState ) => {
    const state = getState( );
    if ( !hasObsAndLoggedIn( state ) ) { return; }
    const newMetrics = _.filter( state.qualityMetrics, qm => (
      !( qm.user && qm.user.id === state.config.currentUser.id && qm.metric === metric ) ) ).concat( [{
        observation_id: state.observation.id,
        metric,
        agree: ( params.agree !== "false" ),
        created_at: moment( ).format( ),
        user: state.config.currentUser,
        api_status: "saving"
      }] );
    dispatch( setQualityMetrics( newMetrics ) );

    const payload = Object.assign( { }, { id: state.observation.id, metric }, params );
    dispatch( callAPI( inatjs.observations.setQualityMetric, payload, {
      fetchQualityMetrics: true } ) );
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
      ( qm.user && qm.user.id === state.config.currentUser.id && qm.metric === metric ) ?
        Object.assign( { }, qm, { api_status: "deleting" } ) : qm
    ) );
    dispatch( setQualityMetrics( newMetrics ) );

    const payload = { id: state.observation.id, metric };
    dispatch( callAPI( inatjs.observations.deleteQualityMetric, payload, {
      fetchQualityMetrics: true } ) );
  };
}

export function addToProjectSubmit( project ) {
  return ( dispatch, getState ) => {
    const state = getState( );
    if ( !hasObsAndLoggedIn( state ) ) { return; }
    const newProjectObs = _.clone( state.observation.project_observations );
    newProjectObs.unshift( {
      project,
      user_id: state.config.currentUser.id,
      user: state.config.currentUser,
      api_status: "saving"
    } );
    dispatch( setAttributes( { project_observations: newProjectObs } ) );

    const payload = { id: project.id, observation_id: state.observation.id };
    const actionTime = getActionTime( );
    inatjs.projects.add( payload ).then( ( ) => {
      dispatch( afterAPICall( { actionTime } ) );
    } ).catch( e => {
      dispatch( handleAPIError( e, `Failed to add to project ${project.title}`, {
        onConfirm: ( ) => {
          const currentProjObs = getState( ).observation.project_observations;
          dispatch( setAttributes( { project_observations:
            _.filter( currentProjObs, po => ( po.project.id !== project.id ) )
          } ) );
        }
      } ) );
    } );
  };
}

export function addToProject( project, options = { } ) {
  return ( dispatch, getState ) => {
    const state = getState( );
    if ( !hasObsAndLoggedIn( state ) ) { return; }
    const missingFields =
      util.observationMissingProjectFields( state.observation, project );
    if ( !_.isEmpty( missingFields ) && !options.ignoreMissing ) {
      // there are empty required project fields, so show the modal
      dispatch( setProjectFieldsModalState( {
        show: true,
        project,
        onSubmit: ( ) => {
          dispatch( setProjectFieldsModalState( { show: false } ) );
          // user may have chosen to leave some non-required fields empty
          dispatch( addToProject( project, { ignoreMissing: true } ) );
        }
      } ) );
      return;
    }
    // there are no empty required fields, so proceed with adding
    dispatch( addToProjectSubmit( project ) );
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
    dispatch( callAPI( inatjs.projects.remove, payload ) );
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

export function addObservationFieldValue( options ) {
  return ( dispatch, getState ) => {
    const state = getState( );
    if ( !hasObsAndLoggedIn( state ) || !options.observationField ) { return; }
    const newOfvs = _.clone( state.observation.ofvs );
    newOfvs.unshift( {
      datatype: options.observationField.datatype,
      name: options.observationField.name,
      value: options.value,
      observation_field: options.observationField,
      api_status: "saving",
      taxon: options.taxon
    } );
    dispatch( setAttributes( { ofvs: newOfvs } ) );
    const payload = {
      observation_field_id: options.observationField.id,
      observation_id: state.observation.id,
      value: options.value
    };
    dispatch( callAPI( inatjs.observation_field_values.create, payload ) );
  };
}

export function updateObservationFieldValue( id, options ) {
  return ( dispatch, getState ) => {
    const state = getState( );
    if ( !hasObsAndLoggedIn( state ) || !options.observationField ) { return; }
    const newOfvs = state.observation.ofvs.map( ofv => (
      ofv.uuid === id ? {
        datatype: options.observationField.datatype,
        name: options.observationField.name,
        value: options.value,
        observation_field: options.observationField,
        api_status: "saving",
        taxon: options.taxon
      } : ofv ) );
    dispatch( setAttributes( { ofvs: newOfvs } ) );
    const payload = {
      id,
      observation_field_id: options.observationField.id,
      observation_id: state.observation.id,
      value: options.value
    };
    dispatch( callAPI( inatjs.observation_field_values.update, payload ) );
  };
}


export function removeObservationFieldValue( id ) {
  return ( dispatch, getState ) => {
    const state = getState( );
    if ( !hasObsAndLoggedIn( state ) ) { return; }
    const newOfvs = state.observation.ofvs.map( ofv => (
      ofv.uuid === id ? Object.assign( { }, ofv, { api_status: "deleting" } ) : ofv ) );
    dispatch( setAttributes( { ofvs: newOfvs } ) );
    dispatch( callAPI( inatjs.observation_field_values.delete, { id } ) );
  };
}

export function onFileDrop( droppedFiles ) {
  return ( dispatch, getState ) => {
    const observation = getState( ).observation;
    if ( !observation || droppedFiles.length === 0 ) { return; }
    const newPhotos = [];
    const newSounds = [];
    const promises = [];
    droppedFiles.forEach( f => {
      if ( f.type.match( /^image\// ) ) {
        newPhotos.push( new inatjs.Photo( { preview: f.preview } ) );
        const params = {
          "observation_photo[observation_id]": observation.id,
          file: f
        };
        promises.push( inatjs.observation_photos.create(
          params, { same_origin: true } ) );
      } else if ( f.type.match( /^audio\// ) ) {
        newSounds.push( { file_url: f.preview } );
        const params = {
          "observation_sound[observation_id]": observation.id,
          file: f
        };
        promises.push( inatjs.observation_sounds.create(
          params, { same_origin: true } ) );
      }
    } );
    if ( newPhotos.length > 0 ) {
      dispatch( setAttributes( { photos: getState( ).observation.photos.concat( newPhotos ) } ) );
    }
    if ( newSounds.length > 0 ) {
      dispatch( setAttributes( { sounds: getState( ).observation.sounds.concat( newSounds ) } ) );
    }
    Promise.all( promises ).then( ( ) => {
      dispatch( afterAPICall( { } ) );
    } ).catch( e => {
      dispatch( afterAPICall( { error: e } ) );
    } );
  };
}

export function showNewObservation( observation, options = { } ) {
  return dispatch => {
    window.scrollTo( 0, 0 );
    const s = windowStateForObservation( observation );
    if ( !( options && options.skipSetState ) ) {
      history.pushState( s.state, s.title, s.url );
    }
    document.title = s.title;
    dispatch( resetStates( ) );
    if ( options.useInstance ) {
      dispatch( renderObservation( observation, { fetchAll: true } ) );
    } else {
      dispatch( fetchObservation( observation.id, { fetchAll: true } ) );
    }
  };
}
