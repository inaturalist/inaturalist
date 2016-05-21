import { connect } from "react-redux";
import SearchBar from "../components/search_bar";
import { fetchObservations, updateSearchParams, reviewAll } from "../actions";

function mapStateToProps( state ) {
  return {
    params: state.searchParams
  };
}

function mapDispatchToProps( dispatch ) {
  return {
    reviewAll: ( ) => {
      dispatch( reviewAll( ) );
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
