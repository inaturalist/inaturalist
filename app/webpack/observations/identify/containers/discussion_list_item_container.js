import { connect } from "react-redux";
import DiscussionListItem from "../components/discussion_list_item";
import { postIdentification, fetchCurrentObservation } from "../actions";

function mapStateToProps( ) {
  return {};
}

function mapDispatchToProps( dispatch ) {
  return {
    agreeWith: ( params ) => {
      dispatch( postIdentification( params ) )
        .then( ( ) => {
          dispatch( fetchCurrentObservation( ) );
        } );
    }
  };
}

const DiscussionListItemContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( DiscussionListItem );

export default DiscussionListItemContainer;
