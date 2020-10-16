import { connect } from "react-redux";

import Content from "../components/content";
import { setUserData, handleInputChange, handleCustomDropdownSelect } from "../ducks/user_settings";

function mapStateToProps( state ) {
  return {
    profile: state.profile
  };
}

function mapDispatchToProps( dispatch ) {
  return {
    setUserData: newState => { dispatch( setUserData( newState ) ); },
    handleInputChange: e => { dispatch( handleInputChange( e ) ); },
    handleCustomDropdownSelect: ( eventKey, name ) => {
      dispatch( handleCustomDropdownSelect( eventKey, name ) );
    }
  };
}

const ContentContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( Content );

export default ContentContainer;
