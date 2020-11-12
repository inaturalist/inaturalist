import { connect } from "react-redux";

import Applications from "../components/applications";
import { setAppToDelete } from "../ducks/authorized_applications";
import { showModal } from "../ducks/revoke_access_modal";

function mapStateToProps( state ) {
  return {
    apps: state.apps.apps
  };
}

function mapDispatchToProps( dispatch ) {
  return {
    showModal: ( id, siteName ) => {
      dispatch( setAppToDelete( id ) );
      dispatch( showModal( id, siteName ) );
    }
  };
}

const ApplicationsContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( Applications );

export default ApplicationsContainer;
