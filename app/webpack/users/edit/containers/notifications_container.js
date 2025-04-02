import { connect } from "react-redux";

import Notifications from "../components/notifications";

function mapStateToProps( state ) {
  return {
    config: state.config,
    profile: state.profile
  };
}

const NotificationsContainer = connect(
  mapStateToProps
)( Notifications );

export default NotificationsContainer;
