import { connect } from "react-redux";

import BlockedMutedUsers from "../components/blocked_muted_users";
import { searchUsers } from "../ducks/user_settings";

function mapStateToProps( state ) {
  return {
    profile: state.profile
  };
}

function mapDispatchToProps( dispatch ) {
  return {
    searchUsers: newState => { dispatch( searchUsers( newState ) ); }
  };
}

const BlockedMutedUsersContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( BlockedMutedUsers );

export default BlockedMutedUsersContainer;
