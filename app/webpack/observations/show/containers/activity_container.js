import { connect } from "react-redux";
import Activity from "../components/activity";
import { addComment, deleteComment, addID, deleteID, restoreID } from "../ducks/observation";

function mapStateToProps( state ) {
  return {
    observation: state.observation,
    config: state.config
  };
}

function mapDispatchToProps( dispatch ) {
  return {
    addComment: ( body ) => { dispatch( addComment( body ) ); },
    deleteComment: ( id ) => { dispatch( deleteComment( id ) ); },
    addID: ( taxonID, body ) => { dispatch( addID( taxonID, body ) ); },
    deleteID: ( id ) => { dispatch( deleteID( id ) ); },
    restoreID: ( id ) => { dispatch( restoreID( id ) ); }
  };
}

const ActivityContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( Activity );

export default ActivityContainer;
