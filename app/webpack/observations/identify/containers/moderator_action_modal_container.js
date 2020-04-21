import { connect } from "react-redux";
import {
  submitModeratorAction,
  hideModeratorActionForm
} from "../../../shared/ducks/moderator_actions";
import ModeratorActionModal from "../../../shared/components/moderator_action_modal";
import { fetchCurrentObservation } from "../actions";

function mapStateToProps( state ) {
  return Object.assign( {}, state.moderatorActions );
}

function mapDispatchToProps( dispatch ) {
  return {
    submit: ( item, action, reason ) => {
      dispatch( submitModeratorAction( item, action, reason ) )
        .then( ( ) => dispatch( fetchCurrentObservation( ) ) );
      dispatch( hideModeratorActionForm( ) );
    },
    hide: ( ) => dispatch( hideModeratorActionForm( ) )
  };
}

const ModeratorActionModalContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( ModeratorActionModal );

export default ModeratorActionModalContainer;
