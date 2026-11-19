import { connect } from "react-redux";
import PhotoDescription, { DescribedPhoto } from "../components/photo_description";
import { setFlaggingModalState } from "../../observations/show/ducks/flagging_modal";
import { showModeratorActionForm, revealHiddenContent } from "../ducks/moderator_actions";
import { performOrOpenConfirmationModal } from "../ducks/user_confirmation";

// eslint-disable-next-line @typescript-eslint/no-explicit-any
function mapStateToProps( state: Record<string, any> ) {
  return {
    currentUser: state.config.currentUser
  };
}

function mapDispatchToProps( dispatch: ( action: unknown ) => void ) {
  return {
    setFlaggingModalState: ( state: object ) => dispatch( setFlaggingModalState( state ) ),
    hideContent: ( item: DescribedPhoto ) => dispatch( showModeratorActionForm( item, "hide" ) ),
    unhideContent: ( item: DescribedPhoto ) => dispatch( showModeratorActionForm( item, "unhide" ) ),
    revealHiddenContent: ( item: DescribedPhoto ) => dispatch( revealHiddenContent( item ) ),
    performOrOpenConfirmationModal: ( method: ( ) => void, options: object ) => (
      dispatch( performOrOpenConfirmationModal( method, options ) )
    )
  };
}

const PhotoDescriptionContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( PhotoDescription );

export default PhotoDescriptionContainer;
