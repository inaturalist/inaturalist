import _ from "lodash";
import inatjs from "inaturalistjs";
import moment from "moment";
import { fetchObservationPlaces } from "./observation_places";
import { fetchControlledTerms } from "./controlled_terms";
import { fetchMoreFromThisUser, fetchNearby, fetchMoreFromClade } from "./other_observations";
import { fetchQualityMetrics, setQualityMetrics } from "./quality_metrics";
import { fetchSubscriptions } from "./subscriptions";
import { fetchIdentifiers } from "./identifications";
import { setFlaggingModalState } from "./flagging_modal";
import { setConfirmModalState, handleAPIError } from "./confirm_modal";
import { updateSession } from "./users";

const SET_OBSERVATION = "obs-show/observation/SET_OBSERVATION";
const SET_ATTRIBUTES = "obs-show/observation/SET_ATTRIBUTES";

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
    return inatjs.observations.fetch( id, params ).then( response => {
      const observation = response.results[0];
      dispatch( setObservation( observation ) );
      dispatch( fetchTaxonSummary( ) );
      if ( options.fetchControlledTerms ) { dispatch( fetchControlledTerms( ) ); }
      if ( options.fetchQualityMetrics ) { dispatch( fetchQualityMetrics( ) ); }
      if ( options.fetchSubscriptions ) { dispatch( fetchSubscriptions( ) ); }
      if ( options.fetchPlaces ) { dispatch( fetchObservationPlaces( ) ); }
      setTimeout( ( ) => {
        if ( options.fetchOtherObservations ) {
          dispatch( fetchMoreFromThisUser( ) );
          dispatch( fetchNearby( ) );
          dispatch( fetchMoreFromClade( ) );
        }
        if ( options.fetchIdentifiers && observation.taxon && observation.taxon.rank_level <= 50 ) {
          dispatch( fetchIdentifiers( { taxon_id: observation.taxon.id, per_page: 10 } ) );
        }
      }, 2000 );
      if ( s.flaggingModal && s.flaggingModal.item && s.flaggingModal.show ) {
        // TODO: put item type in flaggingModal state
        const item = s.flaggingModal.item;
        let newItem;
        if ( id === item.id ) { newItem = observation; }
        newItem = newItem || _.find( observation.comments, c => c.id === item.id );
        newItem = newItem || _.find( observation.identifications, c => c.id === item.id );
        if ( newItem ) { dispatch( setFlaggingModalState( "item", newItem ) ); }
      }
    } );
  };
}

export function updateObservation( attributes ) {
  return ( dispatch, getState ) => {
    const state = getState( );
    if ( !state.observation ) {
      return;
    }
    const attributesToSet = Object.assign( { }, attributes );
    if ( _.has( attributesToSet, "tag_list" ) ) {
      attributesToSet.tags = _.compact(
        _.map( attributesToSet.tag_list.split( "," ), t => ( t.trim( ) ) ) );
    }
    dispatch( setAttributes( attributesToSet ) );
    const payload = {
      id: state.observation.id,
      ignore_photos: true,
      observation: Object.assign( { }, { id: state.observation.id }, attributes )
    };
    inatjs.observations.update( payload ).then( ( ) => {
      dispatch( fetchObservation( state.observation.id ) );
    } ).catch( e => {
      dispatch( handleAPIError( e, I18n.t( "failed_to_save_record" ) ) );
      dispatch( fetchObservation( state.observation.id ) );
    } );
  };
}

export function addComment( body ) {
  return ( dispatch, getState ) => {
    const state = getState( );
    if ( !state.config || !state.config.currentUser || !state.observation ) {
      return;
    }
    dispatch( setAttributes( { comments: state.observation.comments.concat( [{
      created_at: moment( ).format( ),
      user: state.config.currentUser,
      body,
      temporary: true
    }] ) } ) );

    const payload = {
      parent_type: "Observation",
      parent_id: state.observation.id,
      body
    };
    inatjs.comments.create( payload ).then( ( ) => {
      dispatch( fetchObservation( state.observation.id ) );
    } ).catch( e => {
      dispatch( handleAPIError( e, I18n.t( "failed_to_save_record" ) ) );
      dispatch( fetchObservation( state.observation.id ) );
    } );
  };
}

export function deleteComment( id ) {
  return ( dispatch, getState ) => {
    const state = getState( );
    if ( !state.config || !state.config.currentUser || !state.observation ) {
      return;
    }
    dispatch( setAttributes( { comments:
      state.observation.comments.filter( c => ( c.id !== id ) ) } ) );

    const payload = { id };
    inatjs.comments.delete( payload ).then( ( ) => {
      dispatch( fetchObservation( state.observation.id ) );
    } ).catch( e => {
      dispatch( handleAPIError( e, I18n.t( "failed_to_save_record" ) ) );
      dispatch( fetchObservation( state.observation.id ) );
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
    if ( confirmForm && confirmForm.silenceCoarse ) {
      dispatch( updateSession( { prefers_skip_coarer_id_modal: true } ) );
    }
    const observationID = getState( ).observation.id;
    const payload = {
      observation_id: observationID,
      taxon_id: taxon.id,
      body
    };
    inatjs.identifications.create( payload ).then( ( ) => {
      dispatch( fetchObservation( observationID ) );
    } ).catch( e => {
      dispatch( handleAPIError( e, I18n.t( "failed_to_save_record" ) ) );
      dispatch( fetchObservation( observationID ) );
    } );
  };
}

export function addID( taxon, body ) {
  return ( dispatch, getState ) => {
    const observation = getState( ).observation;
    const config = getState( ).config;
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
    const observationID = getState( ).observation.id;
    const payload = { id };
    inatjs.identifications.delete( payload ).then( ( ) => {
      dispatch( fetchObservation( observationID ) );
    } ).catch( e => {
      dispatch( handleAPIError( e, I18n.t( "failed_to_save_record" ) ) );
      dispatch( fetchObservation( observationID ) );
    } );
  };
}

export function restoreID( id ) {
  return ( dispatch, getState ) => {
    const observationID = getState( ).observation.id;
    const payload = {
      id,
      current: true
    };
    inatjs.identifications.update( payload ).then( ( ) => {
      dispatch( fetchObservation( observationID ) );
    } ).catch( e => {
      dispatch( handleAPIError( e, I18n.t( "failed_to_save_record" ) ) );
      dispatch( fetchObservation( observationID ) );
    } );
  };
}

export function vote( scope, params = { } ) {
  return ( dispatch, getState ) => {
    const state = getState( );
    const observationID = getState( ).observation.id;
    const payload = Object.assign( { }, { id: observationID }, params );
    if ( scope ) {
      payload.scope = scope;
      const newVotes = state.observation.votes.concat( [{
        vote_flag: ( params.vote === "yes" ),
        vote_scope: payload.scope,
        user: state.config.currentUser,
        temporary: true
      }] );
      dispatch( setAttributes( { votes: newVotes } ) );
    }
    inatjs.observations.fave( payload ).then( ( ) => {
      dispatch( fetchObservation( observationID ) );
    } ).catch( e => {
      dispatch( handleAPIError( e, I18n.t( "failed_to_save_record" ) ) );
      dispatch( fetchObservation( observationID ) );
    } );
  };
}

export function unvote( scope ) {
  return ( dispatch, getState ) => {
    const state = getState( );
    const payload = { id: state.observation.id };
    if ( scope ) {
      payload.scope = scope;
      const newVotes = state.observation.votes.filter( v => (
        !( v.user.id === state.config.currentUser.id && v.vote_scope === scope )
      ) );
      dispatch( setAttributes( { votes: newVotes } ) );
    }
    inatjs.observations.unfave( payload ).then( ( ) => {
      dispatch( fetchObservation( state.observation.id ) );
    } ).catch( e => {
      dispatch( handleAPIError( e, I18n.t( "failed_to_save_record" ) ) );
      dispatch( fetchObservation( state.observation.id ) );
    } );
  };
}

export function fave( ) {
  return ( dispatch, getState ) => {
    const state = getState( );
    if ( !state.config || !state.config.currentUser || !state.observation ) {
      return;
    }
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
    if ( !state.config || !state.config.currentUser || !state.observation ) {
      return;
    }
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
    if ( !state.config || !state.config.currentUser || !state.observation ) {
      return;
    }
    const newAnnotations = ( state.observation.annotations || [] ).concat( [{
      controlled_attribute: controlledAttribute,
      controlled_value: controlledValue,
      user: state.config.currentUser,
      temporary: true
    }] );
    dispatch( setAttributes( { annotations: newAnnotations } ) );

    const observationID = getState( ).observation.id;
    const payload = {
      resource_type: "Observation",
      resource_id: observationID,
      controlled_attribute_id: controlledAttribute.id,
      controlled_value_id: controlledValue.id
    };
    inatjs.annotations.create( payload ).then( ( ) => {
      dispatch( fetchObservation( observationID ) );
    } ).catch( e => {
      dispatch( handleAPIError( e, I18n.t( "failed_to_save_record" ) ) );
      dispatch( fetchObservation( observationID ) );
    } );
  };
}

export function deleteAnnotation( id ) {
  return ( dispatch, getState ) => {
    const state = getState( );
    if ( !state.config || !state.config.currentUser || !state.observation ) {
      return;
    }
    const newAnnotations = state.observation.annotations.filter( a => (
      !( a.user.id === state.config.currentUser.id && a.uuid === id )
    ) );
    dispatch( setAttributes( { annotations: newAnnotations } ) );

    const payload = { id };
    inatjs.annotations.delete( payload ).then( ( ) => {
      dispatch( fetchObservation( state.observation.id ) );
    } ).catch( e => {
      dispatch( handleAPIError( e, I18n.t( "failed_to_save_record" ) ) );
      dispatch( fetchObservation( state.observation.id ) );
    } );
  };
}

export function voteAnnotation( id, voteValue ) {
  return ( dispatch, getState ) => {
    const state = getState( );
    if ( !state.config || !state.config.currentUser || !state.observation ) {
      return;
    }
    const newAnnotations = Object.assign( { }, state.observation.annotations );
    const annotation = _.find( newAnnotations, a => ( a.uuid === id ) );
    if ( annotation ) {
      annotation.votes = ( annotation.votes || [] ).concat( [{
        vote_flag: ( voteValue !== "bad" ),
        user: state.config.currentUser,
        temporary: true
      }] );
      dispatch( setAttributes( { annotations: newAnnotations } ) );
    }

    const payload = { id, vote: voteValue };
    inatjs.annotations.vote( payload ).then( ( ) => {
      dispatch( fetchObservation( state.observation.id ) );
    } ).catch( e => {
      dispatch( handleAPIError( e, I18n.t( "failed_to_save_record" ) ) );
      dispatch( fetchObservation( state.observation.id ) );
    } );
  };
}

export function unvoteAnnotation( id ) {
  return ( dispatch, getState ) => {
    const state = getState( );
    if ( !state.config || !state.config.currentUser || !state.observation ) {
      return;
    }
    const newAnnotations = Object.assign( { }, state.observation.annotations );
    const annotation = _.find( newAnnotations, a => ( a.uuid === id ) );
    if ( annotation && annotation.votes ) {
      annotation.votes = annotation.votes.filter( v => (
        v.user.id !== state.config.currentUser.id
      ) );
      dispatch( setAttributes( { annotations: newAnnotations } ) );
    }

    const observationID = getState( ).observation.id;
    const payload = { id };
    inatjs.annotations.unvote( payload ).then( ( ) => {
      dispatch( fetchObservation( observationID ) );
    } ).catch( e => {
      dispatch( handleAPIError( e, I18n.t( "failed_to_save_record" ) ) );
      dispatch( fetchObservation( observationID ) );
    } );
  };
}

export function voteMetric( metric, params = { } ) {
  if ( metric === "needs_id" ) {
    return vote( "needs_id", { vote: ( params.agree === "false" ) ? "no" : "yes" } );
  }
  return ( dispatch, getState ) => {
    const state = getState( );
    if ( !state.config || !state.config.currentUser || !state.observation ) {
      return;
    }
    const newMetrics = state.qualityMetrics.concat( [{
      observation_id: state.observation.id,
      metric,
      agree: ( params.agree !== "false" ),
      created_at: moment( ).format( ),
      user: state.config.currentUser
    }] );
    dispatch( setQualityMetrics( newMetrics ) );

    const observationID = getState( ).observation.id;
    const payload = Object.assign( { }, { id: observationID, metric }, params );
    inatjs.observations.setQualityMetric( payload ).then( ( ) => {
      dispatch( fetchObservation( observationID, { fetchQualityMetrics: true } ) );
    } ).catch( e => {
      dispatch( handleAPIError( e, I18n.t( "failed_to_save_record" ) ) );
      dispatch( fetchObservation( observationID, { fetchQualityMetrics: true } ) );
    } );
  };
}

export function unvoteMetric( metric ) {
  if ( metric === "needs_id" ) {
    return unvote( "needs_id" );
  }
  return ( dispatch, getState ) => {
    const state = getState( );
    if ( !state.config || !state.config.currentUser || !state.observation ) {
      return;
    }
    const newMetrics = state.qualityMetrics.filter( qm => (
      !( qm.user.id === state.config.currentUser.id && qm.user_id === qm.metric )
    ) );
    dispatch( setQualityMetrics( newMetrics ) );

    const observationID = getState( ).observation.id;
    const payload = { id: observationID, metric };
    inatjs.observations.deleteQualityMetric( payload ).then( ( ) => {
      dispatch( fetchObservation( observationID, { fetchQualityMetrics: true } ) );
    } ).catch( e => {
      dispatch( handleAPIError( e, I18n.t( "failed_to_save_record" ) ) );
      dispatch( fetchObservation( observationID, { fetchQualityMetrics: true } ) );
    } );
  };
}

export function addToProject( project ) {
  return ( dispatch, getState ) => {
    const state = getState( );
    if ( !state.config || !state.config.currentUser || !state.observation ) {
      return;
    }
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
    if ( !state.config || !state.config.currentUser || !state.observation ) {
      return;
    }
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
