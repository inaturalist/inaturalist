import _ from "lodash";
import React from "react";
import inatjs from "inaturalistjs";
import moment from "moment";
import { fetchObservationPlaces, setObservationPlaces } from "./observation_places";
import { resetControlledTerms } from "./controlled_terms";
import {
  fetchMoreFromThisUser, fetchNearby, fetchMoreFromClade,
  setEarlierUserObservations, setLaterUserObservations, setNearby,
  setMoreFromClade
} from "./other_observations";
import { fetchQualityMetrics, setQualityMetrics } from "./quality_metrics";
import { fetchSubscriptions, resetSubscriptions, setSubscriptions } from "./subscriptions";
import { fetchIdentifiers, setIdentifiers } from "./identifications";
import { setFlaggingModalState } from "./flagging_modal";
import { setConfirmModalState, handleAPIError } from "./confirm_modal";
import { setProjectFieldsModalState } from "./project_fields_modal";
import { updateSession } from "./users";
import util from "../util";
import { showDisagreementAlert } from "../../shared/ducks/disagreement_alert";
import RejectedFilesError from "../../../shared/components/rejected_files_error";

const SET_OBSERVATION = "obs-show/observation/SET_OBSERVATION";
const SET_ATTRIBUTES = "obs-show/observation/SET_ATTRIBUTES";
let lastAction;

const USER_FIELDS = {
  login: true,
  icon_url: true
};
const MODERATOR_ACTION_FIELDS = {
  action: true,
  id: true,
  created_at: true,
  reason: true,
  user: USER_FIELDS
};
const TAXON_FIELDS = {
  ancestry: true,
  ancestor_ids: true,
  ancestors: {
    id: true,
    uuid: true,
    name: true,
    iconic_taxon_name: true,
    is_active: true,
    preferred_common_name: true,
    rank: true,
    rank_level: true
  },
  default_photo: {
    attribution: true,
    license_code: true,
    url: true,
    square_url: true
  },
  iconic_taxon_name: true,
  id: true,
  is_active: true,
  name: true,
  preferred_common_name: true,
  rank: true,
  rank_level: true
};
const CONTROLLED_TERM_FIELDS = {
  id: true,
  label: true,
  multivalued: true
};
const PROJECT_FIELDS = {
  admins: {
    user_id: true
  },
  icon: true,
  project_observation_fields: {
    id: true,
    observation_field: {
      allowed_values: true,
      datatype: true,
      description: true,
      id: true,
      name: true
    }
  },
  slug: true,
  title: true
};
const FIELDS = {
  annotations: {
    controlled_attribute: CONTROLLED_TERM_FIELDS,
    controlled_value: CONTROLLED_TERM_FIELDS,
    user: USER_FIELDS,
    vote_score: true,
    votes: {
      vote_flag: true,
      user: USER_FIELDS
    }
  },
  application: {
    icon: true,
    name: true,
    url: true
  },
  comments: {
    body: true,
    created_at: true,
    flags: { id: true },
    hidden: true,
    id: true,
    moderator_actions: MODERATOR_ACTION_FIELDS,
    spam: true,
    user: USER_FIELDS
  },
  community_taxon: TAXON_FIELDS,
  created_at: true,
  description: true,
  faves: {
    id: true,
    user: USER_FIELDS
  },
  flags: {
    id: true,
    flag: true,
    resolved: true
  },
  geojson: true,
  geoprivacy: true,
  id: true,
  identifications: {
    body: true,
    category: true,
    created_at: true,
    current: true,
    disagreement: true,
    flags: { id: true },
    hidden: true,
    moderator_actions: MODERATOR_ACTION_FIELDS,
    previous_observation_taxon: TAXON_FIELDS,
    spam: true,
    taxon: TAXON_FIELDS,
    taxon_change: { id: true, type: true },
    updated_at: true,
    user: { ...USER_FIELDS, id: true },
    uuid: true,
    vision: true
  },
  identifications_most_agree: true,
  // TODO refactor to rely on geojson instead of lat and lon
  latitude: true,
  license_code: true,
  location: true,
  longitude: true,
  map_scale: true,
  non_traditional_projects: {
    current_user_is_member: true,
    project_user: {
      user: USER_FIELDS
    },
    project: PROJECT_FIELDS
  },
  obscured: true,
  observed_on: true,
  observed_time_zone: true,
  ofvs: {
    observation_field: {
      allowed_values: true,
      datatype: true,
      description: true,
      name: true,
      taxon: {
        name: true
      },
      uuid: true
    },
    user: USER_FIELDS,
    uuid: true,
    value: true,
    taxon: TAXON_FIELDS
  },
  outlinks: {
    source: true,
    url: true
  },
  photos: {
    id: true,
    uuid: true,
    url: true,
    license_code: true
  },
  place_guess: true,
  place_ids: true,
  positional_accuracy: true,
  preferences: {
    prefers_community_taxon: true
  },
  private_geojson: true,
  private_place_guess: true,
  private_place_ids: true,
  project_observations: {
    current_user_is_member: true,
    preferences: {
      allows_curator_coordinate_access: true
    },
    project: PROJECT_FIELDS,
    uuid: true
  },
  public_positional_accuracy: true,
  quality_grade: true,
  reviewed_by: true,
  sounds: {
    file_url: true,
    file_content_type: true,
    id: true,
    license_code: true,
    play_local: true,
    url: true,
    uuid: true
  },
  tags: true,
  taxon: TAXON_FIELDS,
  taxon_geoprivacy: true,
  time_observed_at: true,
  time_zone: true,
  user: {
    ...USER_FIELDS,
    id: true,
    name: true,
    observations_count: true,
    preferences: {
      prefers_community_taxa: true,
      prefers_observation_fields_by: true,
      prefers_project_addition_by: true
    }
  },
  viewer_trusted_by_observer: true,
  votes: {
    id: true,
    user: { ...USER_FIELDS, id: true },
    vote_flag: true,
    vote_scope: true
  }
};

export default function reducer( state = { }, action ) {
  switch ( action.type ) {
    case SET_OBSERVATION: {
      // If we're just updating the same observation, make sure we preserve the
      // existing taxon summaries if the new data doesn't replace them
      if ( action.observation && action.observation.id === state.id ) {
        _.each( ["taxon", "community_taxon", "communityTaxon"], attr => {
          if (
            state[attr]
            && state[attr].taxon_summary
            && action.observation
            && action.observation[attr]
            && !action.observation[attr].taxon_summary
          ) {
            action.observation[attr].taxon_summary = state[attr].taxon_summary;
          }
        } );
      }
      return action.observation;
    }
    case SET_ATTRIBUTES:
      return { ...state, ...action.attributes };
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
export function windowStateForObservation( observation, state, opts = { } ) {
  const options = { hash: "", ...opts };
  const currentUser = state && state.config && state.config.currentUser;
  const observationState = {
    observation: {
      id: observation.id,
      uuid: observation.uuid,
      observed_on: observation.observed_on,
      obscured: observation.obscured,
      user: {
        login: observation.user.login
      }
    }
  };
  let title = `observed by ${observation.user.login}`;
  if ( observation.taxon ) {
    if ( !observation.taxon.preferred_common_name ) {
      title = `${observation.taxon.name} ${title}`;
    } else {
      const commonName = iNatModels.Taxon.titleCaseName( observation.taxon.preferred_common_name );
      if ( currentUser && currentUser.prefers_scientific_name_first ) {
        title = `${observation.taxon.name} (${commonName}) ${title}`;
      } else {
        title = `${commonName} (${observation.taxon.name}) ${title}`;
      }
    }
    observationState.observation.taxon = {
      name: observation.taxon.name,
      preferred_common_name: observation.taxon.preferred_common_name
    };
  } else {
    title = `${I18n.t( "something" )} ${title}`;
  }
  if (
    observation.observed_on
    && observation.obscured
    && !observation.private_geojson
  ) {
    title = `${title} in ${moment( observation.observed_on ).format( I18n.t( "momentjs.month_year" ) )}`;
  } else if ( observation.observed_on ) {
    title = `${title} on ${moment( observation.observed_on ).format( "ll" )}`;
  }
  let url = `/observations/${observation.id}`;
  if ( window.location.search ) {
    url += window.location.search;
  }
  if ( options.hash ) {
    url += options.hash;
  }
  const windowState = {
    state: observationState,
    title: `${title} · ${SITE.name}`,
    url
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
  return (
    hasObsAndLoggedIn( state )
    && state.config.currentUser.id === state.observation.user.id
  );
}

export function resetStates( ) {
  return dispatch => {
    dispatch( setObservation( { } ) );
    dispatch( setIdentifiers( null ) );
    dispatch( setObservationPlaces( [] ) );
    dispatch( resetControlledTerms( ) );
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
    const { observation } = getState( );
    if ( !observation || !observation.taxon ) { return null; }
    const params = { id: observation.uuid, ttl: -1, locale: I18n.locale };
    return inatjs.observations.taxonSummary( params ).then( response => {
      dispatch( setAttributes( {
        taxon: { ...observation.taxon, taxon_summary: response }
      } ) );
    } ).catch( e => console.log( e ) );
  };
}

export function fetchCommunityTaxonSummary( ) {
  return ( dispatch, getState ) => {
    const { observation } = getState( );
    if ( !observation || !observation.communityTaxon ) { return null; }
    const params = {
      id: observation.uuid,
      ttl: -1,
      community: true,
      locale: I18n.locale
    };
    return inatjs.observations.taxonSummary( params ).then( response => {
      dispatch( setAttributes( {
        communityTaxon: {
          ...observation.communityTaxon,
          taxon_summary: response
        }
      } ) );
    } ).catch( e => console.log( e ) );
  };
}

export function fetchNewProjects( ) {
  return ( dispatch, getState ) => {
    const { observation, config } = getState( );
    const { testingApiV2 } = config;
    const params = {
      include_new_projects: "true",
      locale: I18n.locale,
      ttl: -1
    };
    const fetchID = testingApiV2 ? observation.uuid : observation.id;
    return inatjs.observations.fetch( fetchID, params ).then( response => {
      const responseObservation = response.results[0];
      if ( responseObservation && _.has( responseObservation, "non_traditional_projects" ) ) {
        dispatch( setAttributes( {
          non_traditional_projects: responseObservation.non_traditional_projects
        } ) );
      }
    } ).catch( e => console.log( e ) );
  };
}

export function renderObservation( observation, options = { } ) {
  return ( dispatch, getState ) => {
    if ( !observation || !observation.uuid ) {
      console.log( "observation not found" );
      return;
    }
    const s = getState( );
    const originalObservation = s.observation;
    const { fetchAll } = options;
    const taxonUpdated = (
      originalObservation
      && originalObservation.id === observation.id
      && (
        ( !originalObservation.taxon && observation.taxon )
        || ( originalObservation.taxon && !observation.taxon )
        || (
          originalObservation.taxon
          && observation.taxon
          && originalObservation.taxon.id !== observation.taxon.id
        )
      )
    );
    dispatch( setObservation( observation ) );
    if ( taxonUpdated ) {
      dispatch( setIdentifiers( null ) );
      dispatch( setMoreFromClade( [] ) );
    }
    if ( taxonUpdated || fetchAll ) {
      dispatch( fetchTaxonSummary( ) );
      dispatch( fetchCommunityTaxonSummary( ) );
    }
    if ( fetchAll || options.fetchQualityMetrics ) { dispatch( fetchQualityMetrics( ) ); }
    if ( hasObsAndLoggedIn( s ) && ( fetchAll || options.fetchSubscriptions ) ) {
      dispatch( resetSubscriptions( ) );
    }
    if ( fetchAll || options.fetchPlaces ) { dispatch( fetchObservationPlaces( ) ); }
    if ( fetchAll || options.replaceState ) {
      const ws = windowStateForObservation( observation, s, {
        hash: options.replaceState ? window.location.hash : null
      } );
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
      if ( ( fetchAll || taxonUpdated ) && !_.has( observation, "non_traditional_projects" ) ) {
        dispatch( fetchNewProjects( ) );
      }
    }, taxonUpdated ? 1 : 500 );
    if ( s.flaggingModal && s.flaggingModal.item && s.flaggingModal.show ) {
      const { item } = s.flaggingModal;
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

export function fetchObservation( uuid, options = { } ) {
  return ( dispatch, getState ) => {
    if ( !uuid ) {
      return;
    }
    const s = getState( );
    const { testingApiV2 } = s.config;
    const params = {
      include_new_projects: "true",
      preferred_place_id: s.config.preferredPlace ? s.config.preferredPlace.id : null,
      locale: I18n.locale,
      ttl: -1
    };
    if ( testingApiV2 ) {
      params.fields = FIELDS;
    }
    inatjs.observations.fetch( uuid, params ).then( response => {
      dispatch( renderObservation( response.results[0], options ) );
    } ).catch( e => console.log( e ) );
  };
}

export function afterAPICall( options = { } ) {
  return ( dispatch, getState ) => {
    const state = getState( );
    const { testingApiV2 } = state.config;
    if ( options.error ) {
      dispatch(
        handleAPIError(
          options.error,
          options.errorMessage || I18n.t( "failed_to_save_record" )
        )
      );
    }
    if ( options.callback ) {
      options.callback( );
    } else {
      if ( options.actionTime && lastAction !== options.actionTime ) {
        return;
      }
      if ( state.observation ) {
        dispatch(
          fetchObservation(
            testingApiV2 ? state.observation.uuid : state.observation.id,
            options
          )
        );
      }
    }
  };
}

export function callAPI( method, payload, options = { } ) {
  return dispatch => {
    const opts = { ...options };
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
    const { testingApiV2 } = state.config;
    const payload = {
      id: testingApiV2 ? state.observation.uuid : state.observation.id,
      ignore_photos: true,
      observation: attributes
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
    dispatch( setAttributes( {
      tags: state.observation.tags.concat( [{ tag, api_status: "saving" }] )
    } ) );

    let newTagList = tag;
    const { tags } = state.observation;
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
    dispatch( setAttributes( {
      reviewed_by: state.observation.reviewed_by.concat( [
        state.config.currentUser.id
      ] )
    } ) );

    const payload = { uuid: state.observation.uuid };
    dispatch( callAPI( inatjs.observations.review, payload ) );
  };
}

export function unreview( ) {
  return ( dispatch, getState ) => {
    const state = getState( );
    if ( !hasObsAndLoggedIn( state ) ) { return; }
    const newReviewedBy = _.without( state.observation.reviewed_by, state.config.currentUser.id );
    dispatch( setAttributes( { reviewed_by: newReviewedBy } ) );

    const payload = { uuid: state.observation.uuid };
    dispatch( callAPI( inatjs.observations.unreview, payload ) );
  };
}

export function addComment( body ) {
  return ( dispatch, getState ) => {
    const state = getState( );
    if ( !hasObsAndLoggedIn( state ) ) { return; }
    dispatch(
      setAttributes( {
        comments: state.observation.comments.concat( [{
          created_at: moment( ).format( ),
          user: state.config.currentUser,
          body,
          api_status: "saving"
        }] )
      } )
    );

    const payload = {
      comment: {
        parent_type: "Observation",
        parent_id: state.observation.uuid,
        body
      }
    };
    dispatch( callAPI( inatjs.comments.create, payload ) );
  };
}

export function deleteComment( uuid ) {
  return ( dispatch, getState ) => {
    const state = getState( );
    if ( !hasObsAndLoggedIn( state ) ) { return; }
    const newComments = _.map( state.observation.comments, c => (
      c.uuid === uuid ? {
        ...c,
        api_status: "deleting"
      } : c
    ) );
    dispatch( setAttributes( { comments: newComments } ) );
    dispatch( callAPI( inatjs.comments.delete, { uuid } ) );
  };
}

export function editComment( uuid, body ) {
  return ( dispatch, getState ) => {
    const state = getState( );
    if ( !hasObsAndLoggedIn( state ) ) { return; }
    const newComments = state.observation.comments.map( c => (
      c.uuid === uuid ? {
        ...c,
        body,
        api_status: "saving"
      } : c
    ) );
    dispatch( setAttributes( { comments: newComments } ) );
    dispatch( callAPI( inatjs.comments.update, {
      uuid,
      comment: { body }
    } ) );
  };
}

export function confirmDeleteComment( uuid ) {
  return dispatch => {
    dispatch( setConfirmModalState( {
      show: true,
      message: I18n.t( "you_sure_delete_comment?" ),
      confirmText: "Yes",
      onConfirm: ( ) => {
        dispatch( deleteComment( uuid ) );
      }
    } ) );
  };
}

export function doAddID( taxon, confirmForm, options = { } ) {
  return ( dispatch, getState ) => {
    const state = getState( );
    const { testingApiV2 } = state.config;
    if ( !hasObsAndLoggedIn( state ) ) { return; }
    if ( confirmForm && confirmForm.silenceCoarse ) {
      dispatch( updateSession( { prefers_skip_coarer_id_modal: true } ) );
    }
    const newIdentifications = _.map( state.observation.identifications, i => (
      i.user.id === state.config.currentUser.id ? { ...i, current: false } : i
    ) );
    dispatch( setAttributes( {
      identifications: newIdentifications.concat( [{
        created_at: moment( ).format( ),
        user: state.config.currentUser,
        body: options.body,
        agreedTo: options.agreedTo,
        disagreement: options.disagreement,
        taxon,
        current: true,
        api_status: "saving"
      }] )
    } ) );

    const payload = {
      identification: {
        observation_id: testingApiV2 ? state.observation.uuid : state.observation.id,
        taxon_id: taxon.id,
        body: options.body,
        vision: !!taxon.isVisionResult,
        disagreement: options.disagreement
      }
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
    if (
      o.preferences.prefers_community_taxon === false
      || o.user.preferences.prefers_community_taxa === false
    ) {
      observationTaxon = o.community_taxon || o.taxon;
    }
    if (
      observationTaxon
      && taxon.id !== observationTaxon.id
      && _.includes( observationTaxon.ancestor_ids, taxon.id )
    ) {
      dispatch( showDisagreementAlert( {
        onDisagree: ( ) => {
          dispatch( doAddID( taxon, { }, { disagreement: true, ...options } ) );
        },
        onBestGuess: ( ) => {
          dispatch(
            doAddID(
              taxon,
              { disagreement: false },
              { disagreement: false, ...options }
            )
          );
        },
        oldTaxon: observationTaxon,
        newTaxon: taxon
      } ) );
    } else {
      dispatch( doAddID( taxon, null, options ) );
    }
  };
}

export function deleteID( uuid, options = { } ) {
  return ( dispatch, getState ) => {
    const state = getState( );
    if ( !hasObsAndLoggedIn( state ) ) { return; }
    let newIdentifications;
    if ( options.delete ) {
      newIdentifications = _.map( state.observation.identifications, i => (
        i.uuid === uuid ? {
          ...i,
          api_status: "deleting"
        } : i
      ) );
    } else {
      newIdentifications = _.map( state.observation.identifications, i => (
        i.uuid === uuid ? {
          ...i,
          current: false,
          api_status: "deleting"
        } : i
      ) );
    }
    dispatch( setAttributes( { identifications: newIdentifications } ) );
    dispatch( callAPI( inatjs.identifications.delete, { uuid, ...options } ) );
  };
}

export function editID( uuid, body ) {
  return ( dispatch, getState ) => {
    const state = getState( );
    if ( !hasObsAndLoggedIn( state ) ) { return; }
    const newIdentifications = state.observation.identifications.map( i => (
      i.uuid === uuid ? {
        ...i,
        body,
        api_status: "saving"
      } : i
    ) );
    dispatch( setAttributes( { identifications: newIdentifications } ) );
    dispatch( callAPI( inatjs.identifications.update, { uuid, identification: { body } } ) );
  };
}

export function confirmDeleteID( uuid ) {
  return dispatch => {
    dispatch( setConfirmModalState( {
      show: true,
      message: I18n.t( "you_sure_delete_identification?" ),
      confirmText: "Yes",
      onConfirm: ( ) => {
        dispatch( deleteID( uuid, { delete: true } ) );
      }
    } ) );
  };
}

export function withdrawID( uuid ) {
  return ( dispatch, getState ) => {
    const state = getState( );
    if ( !hasObsAndLoggedIn( state ) ) { return; }
    const newIdentifications = _.map( state.observation.identifications, i => (
      i.uuid === uuid
        ? { ...i, current: false, api_status: "saving" }
        : i
    ) );
    dispatch( setAttributes( { identifications: newIdentifications } ) );
    dispatch( callAPI( inatjs.identifications.update, {
      uuid,
      identification: {
        current: false
      }
    } ) );
  };
}

export function restoreID( uuid ) {
  return ( dispatch, getState ) => {
    const state = getState( );
    if ( !hasObsAndLoggedIn( state ) ) { return; }
    const newIdentifications = _.map( state.observation.identifications, i => (
      i.uuid === uuid
        ? { ...i, current: true, api_status: "saving" }
        : i
    ) );
    dispatch( setAttributes( { identifications: newIdentifications } ) );
    dispatch( callAPI( inatjs.identifications.update, {
      uuid,
      identification: {
        current: true
      }
    } ) );
  };
}

export function vote( scope, params = { } ) {
  return ( dispatch, getState ) => {
    const state = getState( );
    if ( !hasObsAndLoggedIn( state ) ) { return; }
    const { testingApiV2 } = state.config;
    const obsID = testingApiV2 ? state.observation.uuid : state.observation.id;
    const payload = { id: obsID, ...params };
    if ( scope ) {
      payload.scope = scope;
      const newVotes = _.filter( state.observation.votes, v => (
        !( v.user.id === state.config.currentUser.id && v.vote_scope === scope )
      ) ).concat( [{
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
    const { testingApiV2 } = state.config;
    const obsID = testingApiV2 ? state.observation.uuid : state.observation.id;
    const payload = { id: obsID };
    if ( scope ) {
      payload.scope = scope;
      const newVotes = _.map( state.observation.votes, v => (
        ( v.user.id === state.config.currentUser.id && v.vote_scope === scope )
          ? { ...v, api_status: "deleting" }
          : v
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
    const newSubscriptions = state.subscriptions.subscriptions.concat( [{
      resource_type: "User",
      resource_id: state.observation.user.id,
      user_id: state.config.currentUser.id,
      api_status: "saving"
    }] );
    dispatch( setSubscriptions( newSubscriptions ) );
    const payload = { id: state.config.currentUser.id, friend_id: state.observation.user.id };
    dispatch( callAPI( inatjs.users.update, payload, {
      callback: ( ) => dispatch( fetchSubscriptions( ) )
    } ) );
  };
}

export function unfollowUser( ) {
  return ( dispatch, getState ) => {
    const state = getState( );
    if ( !hasObsAndLoggedIn( state ) ) { return; }
    if ( userIsObserver( state ) ) { return; }
    const newSubscriptions = _.map( state.subscriptions, s => (
      s.resource_type === "User"
        ? { ...s, api_status: "deleting" }
        : s
    ) );
    dispatch( setSubscriptions( newSubscriptions ) );

    const payload = {
      id: state.config.currentUser.id,
      remove_friend_id: state.observation.user.id
    };
    dispatch( callAPI( inatjs.users.update, payload, {
      callback: ( ) => {
        dispatch( fetchSubscriptions( ) );
      }
    } ) );
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
        s.resource_type === "Observation" ? { ...s, api_status: "deleting" } : s
      ) );
      dispatch( setSubscriptions( newSubscriptions ) );
    } else {
      const newSubscriptions = state.subscriptions.subscriptions.concat( [{
        resource_type: "Observation",
        resource_id: state.observation.id,
        user_id: state.config.currentUser.id,
        api_status: "saving"
      }] );
      dispatch( setSubscriptions( newSubscriptions ) );
    }
    const payload = { id: state.observation.uuid };
    dispatch( callAPI( inatjs.observations.subscribe, payload, {
      callback: ( ) => dispatch( fetchSubscriptions( ) )
    } ) );
  };
}

export function addAnnotation( controlledAttribute, controlledValue ) {
  return ( dispatch, getState ) => {
    const state = getState( );
    if ( !hasObsAndLoggedIn( state ) ) { return; }
    const { testingApiV2 } = state.config;
    const newAnnotations = ( state.observation.annotations || [] ).concat( [{
      controlled_attribute: controlledAttribute,
      controlled_value: controlledValue,
      user: state.config.currentUser,
      api_status: "saving"
    }] );
    dispatch( setAttributes( { annotations: newAnnotations } ) );

    const payload = {
      resource_type: "Observation",
      resource_id: testingApiV2 ? state.observation.uuid : state.observation.id,
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
      ( a.user.id === state.config.currentUser.id && a.uuid === id )
        ? { ...a, api_status: "deleting" }
        : a
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
      ( a.uuid === id )
        ? {
          ...a,
          api_status: "voting",
          votes: ( a.votes || [] ).concat( [{
            vote_flag: ( voteValue !== "bad" ),
            user: state.config.currentUser,
            api_status: "saving"
          }] )
        }
        : a
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
      ( a.uuid === id )
        ? {
          ...a,
          api_status: "voting",
          votes: _.map( a.votes, v => (
            v.user.id === state.config.currentUser.id
              ? { ...v, api_status: "deleting" }
              : v
          ) )
        }
        : a
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
      !( qm.user && qm.user.id === state.config.currentUser.id && qm.metric === metric )
    ) ).concat( [{
      metric,
      agree: ( params.agree !== "false" ),
      created_at: moment( ).format( ),
      user: state.config.currentUser,
      api_status: "saving"
    }] );
    dispatch( setQualityMetrics( newMetrics ) );
    const { testingApiV2 } = state.config;
    const obsID = testingApiV2 ? state.observation.uuid : state.observation.id;
    const payload = { id: obsID, metric, ...params };
    dispatch(
      callAPI(
        inatjs.observations.setQualityMetric,
        payload,
        { fetchQualityMetrics: true }
      )
    );
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
      ( qm.user && qm.user.id === state.config.currentUser.id && qm.metric === metric )
        ? { ...qm, api_status: "deleting" }
        : qm
    ) );
    dispatch( setQualityMetrics( newMetrics ) );
    const { testingApiV2 } = state.config;
    const obsID = testingApiV2 ? state.observation.uuid : state.observation.id;
    const payload = { id: obsID, metric };
    dispatch(
      callAPI(
        inatjs.observations.deleteQualityMetric,
        payload,
        { fetchQualityMetrics: true }
      )
    );
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

    const actionTime = getActionTime( );
    const { testingApiV2 } = state.config;
    const errorHandler = e => {
      dispatch( handleAPIError( e, `Failed to add to project ${project.title}`, {
        onConfirm: ( ) => {
          const currentProjObs = getState( ).observation.project_observations;
          dispatch( setAttributes( {
            project_observations:
              _.filter( currentProjObs, po => ( po.project.id !== project.id ) )
          } ) );
        }
      } ) );
    };
    if ( testingApiV2 ) {
      const payload = {
        project_observation: {
          project_id: project.id,
          observation_id: state.observation.uuid
        }
      };
      inatjs.project_observations.create( payload ).then( ( ) => {
        dispatch( afterAPICall( { actionTime } ) );
      } ).catch( errorHandler );
    } else {
      const payload = { id: project.id, observation_id: state.observation.id };
      inatjs.projects.add( payload ).then( ( ) => {
        dispatch( afterAPICall( { actionTime } ) );
      } ).catch( errorHandler );
    }
  };
}

export function addToProject( project, options = { } ) {
  return ( dispatch, getState ) => {
    const state = getState( );
    if ( !hasObsAndLoggedIn( state ) ) { return; }
    const missingFields = util.observationMissingProjectFields( state.observation, project );
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
    const poToDelete = _.find(
      state.observation.project_observations,
      po => po.project.id === project.id
    );
    const newProjectObs = state.observation.project_observations.filter( po => (
      po.project.id !== project.id
    ) );
    dispatch( setAttributes( { project_observations: newProjectObs } ) );
    const { testingApiV2 } = state.config;
    if ( testingApiV2 ) {
      dispatch( callAPI(
        inatjs.project_observations.delete,
        { id: poToDelete.uuid || poToDelete.id }
      ) );
    } else {
      const payload = { id: project.id, observation_id: state.observation.id };
      dispatch( callAPI( inatjs.projects.remove, payload ) );
    }
  };
}

export function confirmRemoveFromProject( project ) {
  return dispatch => {
    dispatch( setConfirmModalState( {
      show: true,
      message: I18n.t( "are_you_sure_you_want_to_remove_this_observation_from_project", { project: project.title } ),
      confirmText: I18n.t( "yes" ),
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
    const { testingApiV2 } = state.config;
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
      observation_field_value: {
        observation_field_id: options.observationField.id,
        observation_id: testingApiV2 ? state.observation.uuid : state.observation.id,
        value: options.value
      }
    };
    dispatch( callAPI( inatjs.observation_field_values.create, payload ) );
  };
}

export function updateObservationFieldValue( id, options ) {
  return ( dispatch, getState ) => {
    const state = getState( );
    if ( !hasObsAndLoggedIn( state ) || !options.observationField ) { return; }
    const { testingApiV2 } = state.config;
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
      uuid: id,
      observation_field_value: {
        observation_field_id: options.observationField.id,
        observation_id: testingApiV2 ? state.observation.uuid : state.observation.id,
        value: options.value
      }
    };
    dispatch( callAPI( inatjs.observation_field_values.update, payload ) );
  };
}

export function removeObservationFieldValue( id ) {
  return ( dispatch, getState ) => {
    const state = getState( );
    if ( !hasObsAndLoggedIn( state ) ) { return; }
    const newOfvs = state.observation.ofvs.map( ofv => (
      ofv.uuid === id ? { ...ofv, api_status: "deleting" } : ofv ) );
    dispatch( setAttributes( { ofvs: newOfvs } ) );
    dispatch( callAPI( inatjs.observation_field_values.delete, { id } ) );
  };
}

export function onFileDrop( droppedFiles, rejectedFiles, dropEvent ) {
  return ( dispatch, getState ) => {
    const { observation } = getState( );
    if ( rejectedFiles && rejectedFiles.length > 0 ) {
      // eslint-disable-next-line react/jsx-filename-extension
      const message = <RejectedFilesError rejectedFiles={rejectedFiles} />;
      if ( message ) {
        dispatch( setConfirmModalState( {
          show: true,
          message,
          confirmText: I18n.t( "ok" )
        } ) );
      }
    }
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
          params,
          { same_origin: true }
        ) );
      } else if ( f.type.match( /^audio\// ) ) {
        newSounds.push( { file_url: f.preview } );
        const params = {
          "observation_sound[observation_id]": observation.id,
          file: f
        };
        promises.push( inatjs.observation_sounds.create(
          params,
          { same_origin: true }
        ) );
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
  return ( dispatch, getState ) => {
    window.scrollTo( 0, 0 );
    const s = getState( );
    const { testingApiV2 } = s.config;
    const combinedState = windowStateForObservation( observation, getState( ) );
    if ( !( options && options.skipSetState ) ) {
      history.pushState( combinedState.state, combinedState.title, combinedState.url );
    }
    document.title = combinedState.title;
    dispatch( resetStates( ) );
    if ( options.useInstance ) {
      dispatch( renderObservation( observation, { fetchAll: true } ) );
    } else {
      dispatch(
        fetchObservation(
          testingApiV2 ? ( observation.uuid || observation.id ) : observation.id,
          { fetchAll: true }
        )
      );
    }
  };
}

export function fetchTaxonIdentifiers( ) {
  return ( dispatch, getState ) => {
    const { observation } = getState( );
    if ( !( observation.taxon && observation.taxon.rank_level <= 50 ) ) {
      dispatch( setIdentifiers( [] ) );
      return;
    }
    dispatch( fetchIdentifiers( {
      taxon_id: observation.taxon.id, quality_grade: "research", per_page: 10
    } ) );
  };
}
