import { connect } from "react-redux";

import Account from "../components/account";
import {
  handleInputChange,
  handlePlaceAutocomplete,
  handleCustomDropdownSelect
} from "../ducks/user_settings";
import { setModalState } from "../ducks/third_party_tracking_modal";
import { toggleGroup } from "../../../shared/actions/test_groups";

function mapStateToProps( state ) {
  return {
    config: state.config,
    profile: state.profile,
    sites: state.sites.sites
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
    },
    setModalState: newState => { dispatch( setModalState( newState ) ); },
    toggleGroup: group => dispatch( toggleGroup( group ) )
  };
}

const AccountContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( Account );

export default AccountContainer;
