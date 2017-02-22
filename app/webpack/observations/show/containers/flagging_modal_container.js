import { connect } from "react-redux";
import FlaggingModal from "../components/flagging_modal";
import { setState } from "../ducks/flagging_modal";

function mapStateToProps( state ) {
  return {
    state: state.flaggingModal
  };
}

function mapDispatchToProps( dispatch ) {
  return {
    setState: ( key, value ) => { dispatch( setState( key, value ) ); }
  };
}

const FlaggingModalContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( FlaggingModal );

export default FlaggingModalContainer;
