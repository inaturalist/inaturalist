import { connect } from "react-redux";

import Notifications from "../components/notifications";

function mapStateToProps( state ) {
  return {
    profile: state.profile
  };
}

const NotificationsContainer = connect(
  mapStateToProps
)( Notifications );

export default NotificationsContainer;
