import inatjs from "inaturalistjs";
import { setConfig } from "../../../shared/ducks/config";

const SET_PROJECT = "projects-show/project/SET_PROJECT";
const SET_ATTRIBUTES = "projects-show/project/SET_ATTRIBUTES";

export default function reducer( state = { }, action ) {
  switch ( action.type ) {
    case SET_PROJECT:
      return action.project;
    case SET_ATTRIBUTES:
      return Object.assign( { }, state, action.attributes );
    default:
  }
  return state;
}

export function setProject( project ) {
  return {
    type: SET_PROJECT,
    project: Object.assign( { }, project, {
      search_params: {
        project_id: project.id,
        ttl: 300
      }
    } )
  };
}

export function setAttributes( attributes ) {
  return {
    type: SET_ATTRIBUTES,
    attributes
  };
}

export function fetchObservations( ) {
  return ( dispatch, getState ) => {
    const project = getState( ).project;
    if ( !project ) { return null; }
    const params = Object.assign( { }, project.search_params, {
      return_bounds: "true",
      order_by: "popular",
      order: "desc",
      per_page: 100
    } );
    return inatjs.observations.search( params ).then( response => {
      dispatch( setAttributes( {
        observations_loaded: true,
        observations: response,
        observations_page: 1
      } ) );
    } ).catch( e => console.log( e ) );
  };
}

export function infiniteScrollObservations( nextScrollIndex ) {
  return ( dispatch, getState ) => {
    const project = getState( ).project;
    if ( !project || !project.observations_loaded ) { return null; }
    const total = project.observations.total_results;
    const loaded = project.observations.results.length;
    if ( nextScrollIndex > total || nextScrollIndex <= loaded || nextScrollIndex > 200 ) {
      dispatch( setConfig( { observationsScrollIndex: nextScrollIndex } ) );
      return null;
    }
    const params = Object.assign( { }, project.search_params, {
      order_by: "popular",
      order: "desc",
      per_page: 100,
      page: project.observations_page + 1
    } );
    return inatjs.observations.search( params ).then( response => {
      project.observations.results = project.observations.results.concat( response.results );
      dispatch( setAttributes( {
        observations_loaded: true,
        observations: project.observations,
        observations_page: project.observations_page + 1
      } ) );
      dispatch( setConfig( { observationsScrollIndex: nextScrollIndex } ) );
    } ).catch( e => console.log( e ) );
  };
}

export function fetchSpecies( ) {
  return ( dispatch, getState ) => {
    const project = getState( ).project;
    if ( !project ) { return null; }
    return inatjs.observations.speciesCounts( project.search_params ).then( response => {
      dispatch( setAttributes( {
        species_loaded: true,
        species: response
      } ) );
    } ).catch( e => console.log( e ) );
  };
}

export function fetchObservers( ) {
  return ( dispatch, getState ) => {
    const project = getState( ).project;
    if ( !project ) { return null; }
    return inatjs.observations.observers( project.search_params ).then( response => {
      dispatch( setAttributes( {
        observers_loaded: true,
        observers: response
      } ) );
    } ).catch( e => console.log( e ) );
  };
}

export function fetchSpeciesObservers( ) {
  return ( dispatch, getState ) => {
    const project = getState( ).project;
    if ( !project ) { return null; }
    const params = Object.assign( { }, project.search_params, { order_by: "species_count" } );
    return inatjs.observations.observers( params ).then( response => {
      dispatch( setAttributes( {
        species_observers_loaded: true,
        species_observers: response
      } ) );
    } ).catch( e => console.log( e ) );
  };
}


export function fetchIdentifiers( ) {
  return ( dispatch, getState ) => {
    const project = getState( ).project;
    if ( !project ) { return null; }
    return inatjs.observations.identifiers( project.search_params ).then( response => {
      dispatch( setAttributes( {
        identifiers_loaded: true,
        identifiers: response
      } ) );
    } ).catch( e => console.log( e ) );
  };
}

export function fetchOverviewData( ) {
  return dispatch => {
    dispatch( fetchObservations( ) );
    dispatch( fetchSpecies( ) );
    dispatch( fetchObservers( ) );
    dispatch( fetchSpeciesObservers( ) );
    dispatch( fetchIdentifiers( ) );
  };
}

export function setSelectedTab( tab, options = { } ) {
  return dispatch => {
    const newConfigState = {
      selectedTab: tab,
      identifiersScrollIndex: null,
      speciesScrollIndex: null,
      observersScrollIndex: null,
      observationsScrollIndex: null
    };
    const loc = window.location;
    let newURL = `${loc.href.split( /[#?]/ )[0]}`;
    if ( tab !== "overview" ) {
      newURL += `?tab=${tab}`;
    }
    if ( !options.skipState ) {
      if ( options.replaceState ) {
        history.replaceState( newConfigState, document.title, newURL );
      } else {
        history.pushState( newConfigState, document.title, newURL );
      }
    }
    dispatch( setConfig( newConfigState ) );
  };
}

