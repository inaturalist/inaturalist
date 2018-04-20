import _ from "lodash";
import React from "react";
import inatjs from "inaturalistjs";
import { setConfig } from "../../../shared/ducks/config";
import Project from "../../shared/models/project";
import { setConfirmModalState } from "../../../observations/show/ducks/confirm_modal";

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

export function fetchFollowers( ) {
  return ( dispatch, getState ) => {
    const state = getState( );
    const params = { id: state.project.id, per_page: 100 };
    return inatjs.projects.followers( params ).then( response => {
      dispatch( setAttributes( {
        followers_loaded: true,
        followers: response
      } ) );
    } ).catch( e => { } );
  };
}

export function fetchPopularObservations( ) {
  return ( dispatch, getState ) => {
    const project = getState( ).project;
    if ( !project ) { return null; }
    if ( project.popular_observations_loaded ) { return null; }
    const params = Object.assign( { }, project.search_params, {
      per_page: 47,
      popular: true,
      order: "votes"
    } );
    return inatjs.observations.search( params ).then( response => {
      dispatch( setAttributes( {
        popular_observations_loaded: true,
        popular_observations: response
      } ) );
    } ).catch( e => console.log( e ) );
  };
}

export function fetchRecentObservations( ) {
  return ( dispatch, getState ) => {
    const project = getState( ).project;
    if ( !project ) { return null; }
    const params = Object.assign( { }, project.search_params, {
      return_bounds: "true",
      per_page: 50
    } );
    dispatch( setConfig( {
      observationFilters: {
        order_by: "created_at",
        order: "desc"
      }
    } ) );
    return inatjs.observations.search( params ).then( response => {
      dispatch( setAttributes( {
        recent_observations_loaded: true,
        recent_observations: response,
        filtered_observations_loaded: true,
        filtered_observations: response,
        filtered_observations_page: 1
      } ) );
    } ).catch( e => console.log( e ) );
  };
}

export function fetchFilteredObservations( ) {
  return ( dispatch, getState ) => {
    const { project, config } = getState( );
    if ( !project ) { return null; }
    let params = Object.assign( { }, project.search_params, {
      per_page: 50
    } );
    if ( config.observationFilters ) {
      params = Object.assign( params, config.observationFilters );
    }
    dispatch( setAttributes( { filtered_observations_loaded: false } ) );
    return inatjs.observations.search( params ).then( response => {
      dispatch( setAttributes( {
        filtered_observations_loaded: true,
        filtered_observations: response,
        filtered_observations_page: 1
      } ) );
    } ).catch( e => console.log( e ) );
  };
}

export function setObservationFilters( params ) {
  return dispatch => {
    dispatch( setConfig( {
      observationFilters: params,
      observationsScrollIndex: null
    } ) );
    dispatch( fetchFilteredObservations( ) );
  };
}

export function infiniteScrollObservations( nextScrollIndex ) {
  return ( dispatch, getState ) => {
    const { project, config } = getState( );
    if ( !project || !project.filtered_observations_loaded ) { return null; }
    const total = project.filtered_observations_loaded.total_results;
    const loaded = project.filtered_observations.results.length;
    if ( nextScrollIndex > total || nextScrollIndex <= loaded || nextScrollIndex > 500 ) {
      dispatch( setConfig( { observationsScrollIndex: nextScrollIndex } ) );
      return null;
    }
    let params = Object.assign( { }, project.search_params, {
      per_page: 50,
      page: project.filtered_observations_page + 1
    } );
    if ( config.observationFilters ) {
      params = Object.assign( params, config.observationFilters );
    }
    return inatjs.observations.search( params ).then( response => {
      project.filtered_observations.results =
        project.filtered_observations.results.concat( response.results );
      dispatch( setAttributes( {
        filtered_observations: project.filtered_observations,
        filtered_observations_page: project.filtered_observations_page + 1
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
    dispatch( fetchRecentObservations( ) );
    dispatch( fetchSpecies( ) );
    dispatch( fetchObservers( ) );
    dispatch( fetchSpeciesObservers( ) );
    dispatch( fetchIdentifiers( ) );
    dispatch( fetchPosts( ) );
    dispatch( fetchSubscriptions( ) );
    dispatch( fetchFollowers( ) );
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
    if ( project.is_traditional ) {
      urlParams.collection_preview = true;
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
    const { project, config } = getState( );
    if ( !project || !config.currentUser ) { return; }
    const payload = { id: project.id };
    dispatch( setAttributes( {
      follow_status: "saving"
    } ) );
    inatjs.projects.subscribe( payload ).then( ( ) => {
      dispatch( setAttributes( {
        currentUserSubscribed: !project.currentUserSubscribed
      } ) );
      dispatch( fetchSubscriptions( ) );
      dispatch( fetchFollowers( ) );
      dispatch( setAttributes( { follow_status: null } ) );
    } );
  };
}

export function convertProject( ) {
  return ( dispatch, getState ) => {
    const { project } = getState( );
    dispatch( setConfirmModalState( {
      show: true,
      message: (
        <span>
          <span>{ I18n.t( "views.projects.show.are_you_sure_you_want_to_convert" ) }</span>
          <br /><br/>
          <span dangerouslySetInnerHTML={ { __html:
            I18n.t( "views.projects.show.make_sure_you_have_read_about_the_differences",
              { url: "/blog/15450-announcing-changes-to-projects-on-inaturalist" }
            ) } }
          />
        </span>
      ),
      confirmText: I18n.t( "convert" ),
      onConfirm: ( ) => {
        window.location = `/projects/${project.slug}/convert_to_collection`;
      }
    } ) );
  };
}

