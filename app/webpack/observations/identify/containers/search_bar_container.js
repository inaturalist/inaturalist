import { connect } from "react-redux";
import SearchBar from "../components/search_bar";
import { fetchObservations, updateSearchParams, reviewAll, unreviewAll } from "../actions";

function mapStateToProps( state ) {
  return {
    params: state.searchParams,
    allReviewed: state.config.allReviewed
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
    updateSearchParams: ( params ) => {
      dispatch( updateSearchParams( Object.assign( {}, params, { page: 1 } ) ) );
      dispatch( fetchObservations( ) );
    }
  };
}

const ObservationModalContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( SearchBar );

export default ObservationModalContainer;
