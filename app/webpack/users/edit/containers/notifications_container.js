import { connect } from "react-redux";

import Notifications from "../components/notifications";

function mapStateToProps( state ) {
  return {
    userSettings: state.userSettings
  };
}

const NotificationsContainer = connect(
  mapStateToProps
)( Notifications );

export default NotificationsContainer;
