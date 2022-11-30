import { connect } from "react-redux";

import Content from "../components/content";
import {
  handleInputChange,
  handleCustomDropdownSelect,
  handleDisplayNames,
  handlePlaceAutocomplete
} from "../ducks/user_settings";
import { showModal } from "../ducks/cc_licensing_modal";

function mapStateToProps( state ) {
  return {
    config: state.config,
    profile: state.profile
  };
}

function mapDispatchToProps( dispatch ) {
  return {
    handleInputChange: e => { dispatch( handleInputChange( e ) ); },
    handleCustomDropdownSelect: ( eventKey, name ) => {
      dispatch( handleCustomDropdownSelect( eventKey, name ) );
    },
    handleDisplayNames: e => { dispatch( handleDisplayNames( e ) ); },
    handlePlaceAutocomplete: ( e, name ) => {
      dispatch( handlePlaceAutocomplete( e, name ) );
    },
    showModal: ( ) => { dispatch( showModal( ) ); }
  };
}

const ContentContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( Content );

export default ContentContainer;
