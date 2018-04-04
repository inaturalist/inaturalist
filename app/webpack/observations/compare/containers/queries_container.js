import { connect } from "react-redux";
import Queries from "../components/queries";
import {
  addQuery,
  removeQueryAtIndex,
  updateQueryAtIndex,
  fetchDataForTab,
  moveQuery
} from "../ducks/compare";

function mapStateToProps( state ) {
  return {
    queries: state.compare.queries
  };
}

function mapDispatchToProps( dispatch ) {
  return {
    addQuery: ( ) => {
      dispatch( addQuery( ) );
      dispatch( fetchDataForTab( ) );
    },
    removeQueryAtIndex: i => {
      dispatch( removeQueryAtIndex( i ) );
      dispatch( fetchDataForTab( ) );
    },
    updateQueryAtIndex: ( i, updates ) => {
      dispatch( updateQueryAtIndex( i, updates ) );
      dispatch( fetchDataForTab( ) );
    },
    moveQueryUp: i => {
      dispatch( moveQuery( i, i - 1 ) );
    },
    moveQueryDown: i => {
      dispatch( moveQuery( i, i + 1 ) );
    }
  };
}

const QueriesContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( Queries );

export default QueriesContainer;
