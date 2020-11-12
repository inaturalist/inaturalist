import { connect } from "react-redux";
import RevokeAccessModal from "../components/revoke_access_modal";
import { deleteAuthorizedApp } from "../ducks/authorized_applications";
import { hideModal } from "../ducks/revoke_access_modal";

function mapStateToProps( state ) {
  return {
    show: state.revokeAccess.show,
    id: state.revokeAccess.id,
    siteName: state.revokeAccess.siteName
  };
}

function mapDispatchToProps( dispatch ) {
  return {
    onClose: ( ) => { dispatch( hideModal( ) ); },
    deleteApp: id => { dispatch( deleteAuthorizedApp( id ) ); }
  };
}

const RevokeAccessModalContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( RevokeAccessModal );

export default RevokeAccessModalContainer;
