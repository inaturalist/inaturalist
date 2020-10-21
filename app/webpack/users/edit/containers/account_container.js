import { connect } from "react-redux";

import Account from "../components/account";
import { setUserData, handleInputChange, handlePlaceAutocomplete } from "../ducks/user_settings";

function mapStateToProps( state ) {
  return {
    profile: state.profile
  };
}

function mapDispatchToProps( dispatch ) {
  return {
    setUserData: newState => { dispatch( setUserData( newState ) ); },
    handleInputChange: e => { dispatch( handleInputChange( e ) ); },
    handlePlaceAutocomplete: ( e, name ) => {
      dispatch( handlePlaceAutocomplete( e, name ) );
    }
  };
}

const AccountContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( Account );

export default AccountContainer;
