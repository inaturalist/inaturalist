import { connect } from "react-redux";

import Applications from "../components/applications";
import { setAppToDelete } from "../ducks/authorized_applications";
import { showModal } from "../ducks/revoke_access_modal";

function mapStateToProps( state ) {
  return {
    apps: state.apps.apps,
    providerApps: state.apps.providerApps
  };
}

function mapDispatchToProps( dispatch ) {
  return {
    showModal: ( id, siteName, appType ) => {
      dispatch( setAppToDelete( id ) );
      dispatch( showModal( siteName, appType ) );
    }
  };
}

const ApplicationsContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( Applications );

export default ApplicationsContainer;
