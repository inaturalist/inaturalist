import { connect } from "react-redux";
import FlaggingModal from "../components/flagging_modal";
import { setState } from "../ducks/flagging_modal";
import { createFlag, deleteFlag } from "../ducks/flags";

function mapStateToProps( state ) {
  return {
    config: state.config,
    state: state.flaggingModal
  };
}

function mapDispatchToProps( dispatch ) {
  return {
    setState: ( key, value ) => { dispatch( setState( key, value ) ); },
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
