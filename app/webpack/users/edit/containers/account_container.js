import { connect } from "react-redux";

import Account from "../components/account";
import {
  handleInputChange,
  handlePlaceAutocomplete,
  handleCustomDropdownSelect
} from "../ducks/user_settings";

function mapStateToProps( state ) {
  return {
    profile: state.profile
  };
}

function mapDispatchToProps( dispatch ) {
  return {
    handleInputChange: e => { dispatch( handleInputChange( e ) ); },
    handlePlaceAutocomplete: ( e, name ) => {
      dispatch( handlePlaceAutocomplete( e, name ) );
    },
    handleCustomDropdownSelect: ( eventKey, name ) => {
      dispatch( handleCustomDropdownSelect( eventKey, name ) );
    }
  };
}

const AccountContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( Account );

export default AccountContainer;
