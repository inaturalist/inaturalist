import { connect } from "react-redux";
import RevokeAccessModal from "../components/revoke_access_modal";
import { hideModal } from "../ducks/revoke_access_modal";

function mapStateToProps( state ) {
  return {
    show: state.revokeAccess.show
  };
}

function mapDispatchToProps( dispatch ) {
  return {
    onClose: ( ) => { dispatch( hideModal( ) ); }
  };
}

const RevokeAccessModalContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( RevokeAccessModal );

export default RevokeAccessModalContainer;
