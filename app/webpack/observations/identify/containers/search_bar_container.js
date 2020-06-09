import { connect } from "react-redux";
import { setConfig } from "../../../shared/ducks/config";
import SearchBar from "../components/search_bar";
import {
  updateSearchParams,
  replaceSearchParams,
  reviewAll,
  unreviewAll
} from "../actions";

function mapStateToProps( state ) {
  return {
    params: state.searchParams.params,
    defaultParams: state.searchParams.default,
    allReviewed: state.config.allReviewed,
    allControlledTerms: state.controlledTerms.allTerms,
    config: state.config,
    reviewing: state.observations.reviewing
  };
}

function mapDispatchToProps( dispatch ) {
  return {
    reviewAll: ( ) => {
      dispatch( reviewAll( ) );
    },
    unreviewAll: ( ) => {
      dispatch( unreviewAll( ) );
    },
    updateSearchParams: params => {
      dispatch( updateSearchParams( Object.assign( {}, params, { page: 1 } ) ) );
    },
    replaceSearchParams: params => {
      dispatch( replaceSearchParams( Object.assign( {}, params, { page: 1 } ) ) );
    }
  };
}

const ObservationModalContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( SearchBar );

export default ObservationModalContainer;
