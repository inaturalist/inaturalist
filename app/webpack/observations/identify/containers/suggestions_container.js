import { connect } from "react-redux";
import _ from "lodash";
import Sugggestions from "../components/suggestions";
import { setDetailTaxon, updateQuery, fetchSuggestions } from "../ducks/suggestions";
import {
  submitIdentificationWithConfirmation,
  updateCurrentObservation
} from "../actions";

function mapStateToProps( state ) {
  let nextTaxon;
  let prevTaxon;
  if ( state.suggestions.detailTaxon ) {
    const detailTaxonIndex = _.findIndex( state.suggestions.response.results, r =>
      r.taxon.id === state.suggestions.detailTaxon.id );
    const prevResult = state.suggestions.response.results[detailTaxonIndex - 1];
    prevTaxon = prevResult ? prevResult.taxon : null;
    const nextResult = state.suggestions.response.results[detailTaxonIndex + 1];
    nextTaxon = nextResult ? nextResult.taxon : null;
  }
  return Object.assign( {}, state.suggestions, {
    observation: Object.assign( {}, state.currentObservation.observation ),
    prevTaxon,
    nextTaxon
  } );
}

function mapDispatchToProps( dispatch ) {
  return {
    setDetailTaxon: ( taxon, options = {} ) => {
      dispatch( setDetailTaxon( taxon, options ) );
    },
    setQuery: query => {
      dispatch( updateQuery( query ) );
      dispatch( fetchSuggestions( ) );
    },
    chooseTaxon: ( taxon, options = {} ) => {
      const ident = {
        observation_id: options.observation.id,
        taxon_id: taxon.id,
        vision: options.vision
      };
      dispatch( updateCurrentObservation( { tab: "info" } ) );
      dispatch( submitIdentificationWithConfirmation( ident, {
        confirmationText: options.confirmationText
      } ) );
    }
  };
}

const SuggestionsContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( Sugggestions );

export default SuggestionsContainer;
