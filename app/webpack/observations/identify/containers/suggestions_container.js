import { connect } from "react-redux";
import _ from "lodash";
import { updateCurrentUser } from "../../../shared/ducks/config";
import Sugggestions from "../components/suggestions";
import {
  setDetailTaxon,
  updateQuery,
  fetchSuggestions,
  fetchDetailTaxon
} from "../ducks/suggestions";
import { performOrOpenConfirmationModal } from "../../../shared/ducks/user_confirmation";
import {
  onSubmitIdentification
} from "../actions";

function mapStateToProps( state ) {
  let nextTaxon;
  let prevTaxon;
  if ( state.suggestions.detailTaxon ) {
    const detailTaxonIndex = _.findIndex(
      state.suggestions.response.results,
      r => r.taxon.id === state.suggestions.detailTaxon.id
    );
    const prevResult = state.suggestions.response.results[detailTaxonIndex - 1];
    prevTaxon = prevResult ? prevResult.taxon : null;
    const nextResult = state.suggestions.response.results[detailTaxonIndex + 1];
    nextTaxon = nextResult ? nextResult.taxon : null;
  }
  return Object.assign( {}, state.suggestions, {
    observation: Object.assign( {}, state.currentObservation.observation ),
    prevTaxon,
    nextTaxon,
    config: state.config
  } );
}

function mapDispatchToProps( dispatch, ownProps ) {
  return {
    onSubmitIdentification: ( identification, options = {} ) => {
      dispatch( onSubmitIdentification( ownProps.observation, identification, options ) );
    },
    setDetailTaxon: ( taxon, options = {} ) => {
      dispatch( setDetailTaxon( taxon, options ) );
      dispatch( fetchDetailTaxon( ) );
    },
    setQuery: ( query, options ) => {
      dispatch( updateQuery( query, options ) );
      dispatch( fetchSuggestions( ) );
    },
    updateCurrentUser: updates => dispatch( updateCurrentUser( updates ) ),
    performOrOpenConfirmationModal: ( method, options = { } ) => (
      dispatch( performOrOpenConfirmationModal( method, options ) )
    )
  };
}

const SuggestionsContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( Sugggestions );

export default SuggestionsContainer;
