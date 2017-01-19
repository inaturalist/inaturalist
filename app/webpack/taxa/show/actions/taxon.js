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

export function showNewTaxon( taxon ) {
  return dispatch => dispatch( fetchTaxon( taxon ) )
    .then( ( ) => {
      const s = windowStateForTaxon( taxon );
      history.pushState( s.state, s.title, s.url );
      document.title = s.title;
      $( "a[href=#charts-seasonality]" ).tab( "show" );
      dispatch( resetLeadersState( ) );
      dispatch( resetObservationsState( ) );
      dispatch( fetchTaxonAssociates( taxon ) );
    } );
}
