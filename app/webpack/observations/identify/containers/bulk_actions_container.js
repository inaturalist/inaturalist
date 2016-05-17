import { connect } from "react-redux";
import BulkActions from "../components/bulk_actions";
import { reviewAll, unreviewAll } from "../actions";

function mapStateToProps( ) {
  return {};
}

function mapDispatchToProps( dispatch ) {
  return {
    reviewAll: ( ) => {
      dispatch( reviewAll( ) );
    },
    unreviewAll: ( ) => {
      dispatch( unreviewAll( ) );
    }
  };
}

const BulkActionsContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( BulkActions );

export default BulkActionsContainer;
