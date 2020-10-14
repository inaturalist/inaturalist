import { connect } from "react-redux";

import Content from "../components/content";
import { setUserData, handleInputChange } from "../ducks/user_settings";

function mapStateToProps( state ) {
  return {
    profile: state.profile
  };
}

function mapDispatchToProps( dispatch ) {
  return {
    setUserData: newState => { dispatch( setUserData( newState ) ); },
    handleInputChange: newState => { dispatch( handleInputChange( newState ) ); }
  };
}

const ContentContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( Content );

export default ContentContainer;
