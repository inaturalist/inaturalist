import _ from "lodash";
import inatjs from "inaturalistjs";
import { setConfig } from "../../../shared/ducks/config";
import Project from "../../shared/models/project";

const SET_PROJECT = "projects-show/project/SET_PROJECT";
const SET_ATTRIBUTES = "projects-show/project/SET_ATTRIBUTES";

export default function reducer( state = { }, action ) {
  switch ( action.type ) {
    case SET_PROJECT:
      return action.project;
    case SET_ATTRIBUTES:
      return new Project( Object.assign( { }, state, action.attributes ) );
    default:
  }
  return state;
}

export function setProject( project ) {
  return {
    type: SET_PROJECT,
    project: new Project( project )
  };
}

export function setAttributes( attributes ) {
  return {
    type: SET_ATTRIBUTES,
    attributes
  };
}

export function fetchSubscriptions( ) {
  return ( dispatch, getState ) => {
    const state = getState( );
    if ( !state.project || !state.config.currentUser ) { return null; }
    const params = { id: state.project.id };
    return inatjs.projects.subscriptions( params ).then( response => {
      dispatch( setAttributes( {
        currentUserSubscribed: !_.isEmpty( response.results )
      } ) );
    } ).catch( e => { } );
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
    if ( nextScrollIndex > total || nextScrollIndex <= loaded || nextScrollIndex > 500 ) {
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

export function fetchPosts( ) {
  return ( dispatch, getState ) => {
    const project = getState( ).project;
    if ( !project ) { return null; }
    return inatjs.projects.posts( { id: project.id, per_page: 3 } ).then( response => {
      dispatch( setAttributes( {
        posts_loaded: true,
        posts: response
      } ) );
    } ).catch( e => console.log( e ) );
  };
}

export function fetchIconicTaxaCounts( ) {
  return ( dispatch, getState ) => {
    const project = getState( ).project;
    if ( !project ) { return null; }
    return inatjs.observations.iconicTaxaSpeciesCounts( project.search_params ).then( response => {
      dispatch( setAttributes( {
        iconic_taxa_species_counts_loaded: true,
        iconic_taxa_species_counts: response
      } ) );
    } ).catch( e => console.log( e ) );
  };
}

export function fetchUmbrellaStats( ) {
  return ( dispatch, getState ) => {
    const project = getState( ).project;
    if ( !project ) { return null; }
    const statsParams = { project_id: project.id };
    return inatjs.observations.umbrellaProjectStats( statsParams ).then( response => {
      dispatch( setAttributes( {
        umbrella_stats_loaded: true,
        umbrella_stats: response
      } ) );
    } ).catch( e => console.log( e ) );
  };
}

export function fetchQualityGradeCounts( ) {
  return ( dispatch, getState ) => {
    const project = getState( ).project;
    if ( !project || project.quality_grade_counts_loading ||
         project.quality_grade_counts_loaded ) { return null; }
    dispatch( setAttributes( {
      quality_grade_counts_loading: true
    } ) );
    return inatjs.observations.qualityGrades( project.search_params ).then( response => {
      dispatch( setAttributes( {
        quality_grade_counts_loading: false,
        quality_grade_counts_loaded: true,
        quality_grade_counts: response
      } ) );
    } ).catch( e => console.log( e ) );
  };
}

export function fetchIdentificationCategories( ) {
  return ( dispatch, getState ) => {
    const project = getState( ).project;
    if ( !project || project.identification_categories_loading ||
        project.identification_categories_loaded ) { return null; }
    dispatch( setAttributes( {
      identification_categories_loading: true
    } ) );
    return inatjs.observations.identificationCategories( project.search_params ).then( response => {
      dispatch( setAttributes( {
        identification_categories_loading: false,
        identification_categories_loaded: true,
        identification_categories: response
      } ) );
    } ).catch( e => console.log( e ) );
  };
}

export function fetchOverviewData( ) {
  return ( dispatch, getState ) => {
    const project = getState( ).project;
    if ( project.project_type === "umbrella" ) {
      dispatch( fetchUmbrellaStats( ) );
    }
    dispatch( fetchSubscriptions( ) );
    dispatch( fetchObservations( ) );
    dispatch( fetchSpecies( ) );
    dispatch( fetchObservers( ) );
    dispatch( fetchSpeciesObservers( ) );
    dispatch( fetchIdentifiers( ) );
    dispatch( fetchPosts( ) );
    dispatch( fetchIconicTaxaCounts( ) );
  };
}

export function setSelectedTab( tab, options = { } ) {
  return ( dispatch, getState ) => {
    const { project, config } = getState( );
    const newConfigState = {
      selectedTab: tab,
      identifiersScrollIndex: null,
      speciesScrollIndex: null,
      observersScrollIndex: null,
      observationsScrollIndex: null
    };
    const loc = window.location;
    let newURL = `${loc.href.split( /[#?]/ )[0]}`;
    const urlParams = { };
    if ( tab && tab !== "overview" && tab !== "umbrella_overview" ) {
      urlParams.tab = tab;
    }
    if ( options.subtab ) {
      urlParams.subtab = options.subtab;
      newConfigState.observationsSearchSubview = options.subtab;
    } else if ( tab === "observations" && config.observationsSearchSubview ) {
      urlParams.subtab = config.observationsSearchSubview;
    }
    if ( project.collection_ids ) {
      urlParams.collection_id = project.collection_ids.join( "," );
    }
    if ( !_.isEmpty( urlParams ) ) {
      newURL += `?${$.param( urlParams )}`;
    }
    if ( !options.skipState ) {
      if ( options.replaceState ) {
        history.replaceState( newConfigState, document.title, newURL );
      } else {
        history.pushState( newConfigState, document.title, newURL );
      }
    }
    if ( tab === "about" ) {
      window.scrollTo( 0, 0 );
    }
    dispatch( setConfig( newConfigState ) );
  };
}

export function subscribe( ) {
  return ( dispatch, getState ) => {
    const state = getState( );
    if ( !state.project || !state.config.currentUser ) { return; }
    const payload = { id: state.project.id };
    inatjs.projects.subscribe( payload ).then( response => {
      dispatch( fetchSubscriptions( ) );
    } );
  };
}

