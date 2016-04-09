import { connect } from "react-redux";
import DiscussionListItem from "../components/discussion_list_item";
import { postIdentification } from "../actions";

function mapStateToProps( ) {
  return {};
}

function mapDispatchToProps( dispatch ) {
  return {
    agreeWith: ( params ) => {
      dispatch( postIdentification( params ) );
    }
  };
}

const DiscussionListItemContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( DiscussionListItem );

export default DiscussionListItemContainer;
