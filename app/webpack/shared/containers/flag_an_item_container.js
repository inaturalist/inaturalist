import { connect } from "react-redux";
import FlagAnItem from "../components/flag_an_item";
import { setFlaggingModalState } from "../../observations/show/ducks/flagging_modal";

function mapStateToProps( state ) {
  return {
    config: state.config
  };
}

function mapDispatchToProps( dispatch ) {
  return {
    setFlaggingModalState: newState => dispatch( setFlaggingModalState( newState ) )
  };
}

const FlagAnItemContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( FlagAnItem );

export default FlagAnItemContainer;
