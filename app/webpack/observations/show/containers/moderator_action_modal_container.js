import { connect } from "react-redux";
import {
  submitModeratorAction,
  hideModeratorActionForm,
  revealHiddenContent
} from "../../../shared/ducks/moderator_actions";
import { afterAPICall, setItemAPIStatus } from "../ducks/observation";
import ModeratorActionModal from "../../../shared/components/moderator_action_modal";

function mapStateToProps( state ) {
  return {
    ...state.moderatorActions,
    config: state.config
  };
}

function mapDispatchToProps( dispatch ) {
  return {
    submit: ( item, action, reason ) => {
      dispatch( setItemAPIStatus( item, "processing" ) );
      dispatch( submitModeratorAction( item, action, reason ) )
        .then( ( ) => dispatch( afterAPICall( ) ) )
        .catch( e => dispatch( afterAPICall( { error: e } ) ) );
      dispatch( hideModeratorActionForm( ) );
    },
    hide: ( ) => dispatch( hideModeratorActionForm( ) ),
    revealHiddenContent: item => dispatch( revealHiddenContent( item ) )
  };
}

const ModeratorActionModalContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( ModeratorActionModal );

export default ModeratorActionModalContainer;
