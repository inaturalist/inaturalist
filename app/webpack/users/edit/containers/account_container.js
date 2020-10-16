import { connect } from "react-redux";

import Account from "../components/account";
import { setUserData, handleInputChange } from "../ducks/user_settings";

function mapStateToProps( state ) {
  return {
    profile: state.profile
  };
}

function mapDispatchToProps( dispatch ) {
  return {
    setUserData: newState => { dispatch( setUserData( newState ) ); },
    handleInputChange: e => { dispatch( handleInputChange( e ) ); }
  };
}

const AccountContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( Account );

export default AccountContainer;
