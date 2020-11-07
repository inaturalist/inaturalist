import { connect } from "react-redux";

import BlockedMutedUsers from "../components/blocked_muted_users";
import { blockUser, muteUser } from "../ducks/relationships";

function mapStateToProps( state ) {
  return {
    profile: state.profile
  };
}

function mapDispatchToProps( dispatch ) {
  return {
    blockOrMute: ( item, id ) => {
      if ( id === "blocked_users" ) {
        dispatch( blockUser( item.user_id ) );
      } else {
        dispatch( muteUser( item.user_id ) );
      }
    }
  };
}

const BlockedMutedUsersContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( BlockedMutedUsers );

export default BlockedMutedUsersContainer;
