import { connect } from "react-redux";

import Applications from "../components/applications";
import { showModal } from "../ducks/revoke_access_modal";

function mapStateToProps( ) {
  return {};
}

function mapDispatchToProps( dispatch ) {
  return {
    showModal: ( ) => {
      // dispatch( setModal( application ) );
      dispatch( showModal( ) );
    }
  };
}

const ApplicationsContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( Applications );

export default ApplicationsContainer;
