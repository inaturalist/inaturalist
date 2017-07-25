import { connect } from "react-redux";
import Sugggestions from "../components/suggestions";
import { setDetailTaxon, updateQuery, fetchSuggestions } from "../ducks/suggestions";
import {
  submitIdentificationWithConfirmation,
  updateCurrentObservation
} from "../actions";

function mapStateToProps( state ) {
  return Object.assign( {}, state.suggestions, {
    observation: Object.assign( {}, state.currentObservation.observation )
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
