import { connect } from "react-redux";
import MarkAllAsReviewedButton from "../components/mark_all_as_reviewed_button";
import {
  reviewAll,
  unreviewAll
} from "../actions";

function mapStateToProps( state ) {
  return {
    allReviewed: state.config.allReviewed,
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
    }
  };
}

const MarkAllAsReviewedButtonContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( MarkAllAsReviewedButton );

export default MarkAllAsReviewedButtonContainer;
