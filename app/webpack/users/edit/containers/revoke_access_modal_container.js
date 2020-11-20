import { connect } from "react-redux";
import RevokeAccessModal from "../components/revoke_access_modal";
import { deleteAuthorizedApp } from "../ducks/authorized_applications";
import { hideModal } from "../ducks/revoke_access_modal";

function mapStateToProps( state ) {
  const { revokeAccess } = state;
  return {
    show: revokeAccess.show,
    siteName: revokeAccess.siteName,
    official: revokeAccess.official
  };
}

function mapDispatchToProps( dispatch ) {
  return {
    onClose: ( ) => { dispatch( hideModal( ) ); },
    deleteApp: ( ) => {
      dispatch( deleteAuthorizedApp( ) );
      dispatch( hideModal( ) );
    }
  };
}

const RevokeAccessModalContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( RevokeAccessModal );

export default RevokeAccessModalContainer;
