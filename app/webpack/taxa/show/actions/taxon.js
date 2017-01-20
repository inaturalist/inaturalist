import {
  fetchTaxon,
  setCount,
  fetchTaxonChange,
  fetchNames,
  fetchTerms
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
    const taxon = t || getState( ).taxon.taxon;
    if ( taxon.taxon_changes_count ) {
      dispatch( setCount( "taxonChangesCount", taxon.taxon_changes_count ) );
      if ( taxon.taxon_changes_count > 0 ) {
        dispatch( fetchTaxonChange( taxon ) );
      }
    }
    if ( taxon.taxon_schemes_count ) {
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
