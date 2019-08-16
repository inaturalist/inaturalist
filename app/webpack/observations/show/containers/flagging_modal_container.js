import { connect } from "react-redux";
import FlaggingModal from "../components/flagging_modal";
import { setFlaggingModalState } from "../ducks/flagging_modal";
import { createFlag, deleteFlag } from "../ducks/flags";

function mapStateToProps( state ) {
  return {
    config: state.config,
    state: state.flaggingModal,
    radioOptions: state.flaggingModal.radioOptions
  };
}

function mapDispatchToProps( dispatch ) {
  return {
    setFlaggingModalState: newState => dispatch( setFlaggingModalState( newState ) ),
    createFlag: ( className, id, flag, body ) => {
      dispatch( createFlag( className, id, flag, body ) );
    },
    deleteFlag: id => dispatch( deleteFlag( id ) )
  };
}

const FlaggingModalContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( FlaggingModal );

export default FlaggingModalContainer;
