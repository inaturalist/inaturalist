import { connect } from "react-redux";
import FlaggingModal from "../../../observations/show/components/flagging_modal";
import { setFlaggingModalState } from "../../../observations/show/ducks/flagging_modal";
import { createFlag, deleteFlag } from "../ducks/project";

function mapStateToProps( state ) {
  return {
    config: state.config,
    state: state.flaggingModal
  };
}

function mapDispatchToProps( dispatch ) {
  return {
    setFlaggingModalState: ( newState ) => { dispatch( setFlaggingModalState( newState ) ); },
    createFlag: ( className, id, flag, body ) => {
      dispatch( createFlag( className, id, flag, body ) );
    },
    deleteFlag: id => { dispatch( deleteFlag( id ) ); }
  };
}

const FlaggingModalContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( FlaggingModal );

export default FlaggingModalContainer;
