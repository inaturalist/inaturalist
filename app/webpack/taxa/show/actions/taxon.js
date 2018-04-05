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
  fetchWanted,
  fetchRecent,
  fetchSimilar
} from "../../shared/ducks/taxon";
import {
  fetchMonthFrequency,
  fetchMonthOfYearFrequency,
  resetObservationsState
} from "../ducks/observations";
import { fetchLeaders, resetLeadersState } from "../ducks/leaders";
import { windowStateForTaxon } from "../../shared/util";

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
    dispatch( fetchLeaders( taxon ) ).then( ( ) => {
      dispatch( fetchTerms( ( ) => {
        dispatch( fetchMonthOfYearFrequency( taxon ) ).then( ( ) => {
          dispatch( fetchMonthFrequency( taxon ) );
        } );
      } ) );
    } );
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
        dispatch( fetchWanted( ) );
        dispatch( fetchRecent( ) );
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
