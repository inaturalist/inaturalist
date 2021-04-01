import _ from "lodash";
import {
  fetchTaxon,
  setCount,
  fetchTaxonChange,
  fetchNames,
  fetchTerms,
  fetchSpecies,
  fetchDescription,
  fetchLinks,
  fetchInteractions,
  fetchTrending,
  fetchSimilar
} from "../../shared/ducks/taxon";
import {
  fetchMonthOfYearFrequency,
  resetObservationsState,
  fetchMonthOfYearFrequencyBackground,
  fetchMonthFrequencyBackground
} from "../ducks/observations";
import { fetchLeaders, resetLeadersState } from "../ducks/leaders";
import { windowStateForTaxon } from "../../shared/util";
import { setConfig } from "../../../shared/ducks/config";

export function fetchTaxonAssociates( t ) {
  return ( dispatch, getState ) => {
    dispatch( resetLeadersState( ) );
    dispatch( resetObservationsState( ) );
    const s = getState( );
    const taxon = t || s.taxon.taxon;
    if ( !_.isNil( taxon.taxon_changes_count ) ) {
      dispatch( setCount( "taxonChangesCount", taxon.taxon_changes_count ) );
      if ( taxon.taxon_changes_count > 0 ) {
        dispatch( fetchTaxonChange( taxon ) );
      }
    }
    if ( !_.isNil( taxon.taxon_schemes_count ) ) {
      dispatch( setCount( "taxonSchemesCount", taxon.taxon_schemes_count ) );
    }
    dispatch( fetchNames( ) );
    dispatch( fetchLeaders( taxon ) )
      .then( ( ) => dispatch( fetchTerms( ) ) )
      .then( ( ) => dispatch( fetchMonthOfYearFrequency( taxon ) ) );
    if ( taxon.complete_species_count ) {
      dispatch( fetchSpecies( ) );
    }
    switch ( s.config.chosenTab ) {
      case "articles":
        dispatch( fetchDescription( ) );
        dispatch( fetchLinks( ) );
        break;
      case "taxonomy":
        dispatch( fetchNames( ) );
        break;
      case "interactions":
        dispatch( fetchInteractions( ) );
        break;
      case "highlights":
        dispatch( fetchTrending( ) );
        break;
      case "similar":
        dispatch( fetchSimilar( ) );
        break;
      default:
        // it's cool, you probably have what you need
    }
  };
}

export function showNewTaxon( taxon, options ) {
  return dispatch => {
    dispatch( fetchTaxon( taxon ) ).then( ( ) => {
      // scroll to the top of the page when rendering a new taxon
      // (except when specified, e.g. on the taxonomy tab taxon links)
      if ( !( options && options.skipScrollTop === true ) ) {
        window.scrollTo( 0, 0 );
      }
      const s = windowStateForTaxon( taxon );
      history.pushState( s.state, s.title, s.url );
      document.title = s.title;
      dispatch( fetchTaxonAssociates( taxon ) );
    } );
  };
}

export function setNoAnnotationHiddenPreference( pref ) {
  return dispatch => {
    dispatch( setConfig( { prefersNoAnnotationHidden: pref } ) );
  };
}

export function setScaledPreference( pref ) {
  return ( dispatch, getState ) => {
    dispatch( setConfig( { prefersScaledFrequencies: pref } ) );
    if ( !getState( ).observations.monthOfYearFrequency.background ) {
      dispatch( fetchMonthOfYearFrequencyBackground( ) );
    }
    if ( !getState( ).observations.monthFrequency.background ) {
      dispatch( fetchMonthFrequencyBackground( ) );
    }
  };
}
