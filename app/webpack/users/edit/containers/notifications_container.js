import { connect } from "react-redux";

import Notifications from "../components/notifications";
import { handleCheckboxChange } from "../ducks/user_settings";

function mapStateToProps( state ) {
  return {
    profile: state.profile
  };
}

function mapDispatchToProps( dispatch ) {
  return {
    handleCheckboxChange: e => { dispatch( handleCheckboxChange( e ) ); }
  };
}

const NotificationsContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( Notifications );

export default NotificationsContainer;
