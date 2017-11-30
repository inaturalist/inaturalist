import { connect } from "react-redux";
import Activity from "../components/activity";
import { addComment, confirmDeleteComment, addID, deleteID, restoreID,
  review, unreview } from "../ducks/observation";
import { setFlaggingModalState } from "../ducks/flagging_modal";
import { createFlag, deleteFlag } from "../ducks/flags";
import { setActiveTab } from "../ducks/comment_id_panel";

function mapStateToProps( state ) {
  return {
    observation: state.observation,
    config: state.config,
    commentIDPanel: state.commentIDPanel
  };
}

function mapDispatchToProps( dispatch ) {
  return {
    setFlaggingModalState: ( newState ) => { dispatch( setFlaggingModalState( newState ) ); },
    addComment: body => { dispatch( addComment( body ) ); },
    deleteComment: id => { dispatch( confirmDeleteComment( id ) ); },
    addID: ( taxon, options ) => { dispatch( addID( taxon, options ) ); },
    deleteID: id => { dispatch( deleteID( id ) ); },
    restoreID: id => { dispatch( restoreID( id ) ); },
    createFlag: ( className, id, flag, body ) => {
      dispatch( createFlag( className, id, flag, body ) );
    },
    deleteFlag: id => { dispatch( deleteFlag( id ) ); },
    setActiveTab: activeTab => { dispatch( setActiveTab( activeTab ) ); },
    review: ( ) => { dispatch( review( ) ); },
    unreview: ( ) => { dispatch( unreview( ) ); }
  };
}

const ActivityContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( Activity );

export default ActivityContainer;
