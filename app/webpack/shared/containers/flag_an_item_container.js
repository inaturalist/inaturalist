import { connect } from "react-redux";
import FlagAnItem from "../components/flag_an_item";
import { setFlaggingModalState } from "../../observations/show/ducks/flagging_modal";
import { performOrOpenConfirmationModal } from "../ducks/user_confirmation";

function mapStateToProps( state ) {
  return {
    config: state.config
  };
}

function mapDispatchToProps( dispatch ) {
  return {
    setFlaggingModalState: newState => dispatch( setFlaggingModalState( newState ) ),
    performOrOpenConfirmationModal: ( method, options = { } ) => (
      dispatch( performOrOpenConfirmationModal( method, options ) )
    )
  };
}

const FlagAnItemContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( FlagAnItem );

export default FlagAnItemContainer;
