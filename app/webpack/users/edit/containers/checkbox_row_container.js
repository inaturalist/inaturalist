import { connect } from "react-redux";

import { showAlert } from "../../../shared/ducks/alert_modal";
import CheckboxRow from "../components/checkbox_row";
import { handleCheckboxChange } from "../ducks/user_settings";

function mapStateToProps( state ) {
  return {
    profile: state.profile
  };
}

function mapDispatchToProps( dispatch ) {
  return {
    handleCheckboxChange: newState => dispatch( handleCheckboxChange( newState ) ),
    confirmChangeTo: ( name, msg, event ) => {
      const { target } = event;
      // This is a fake event object that handleCheckboxChange can use.
      // event.target seems to dissapear after preventDefault( )
      const confirmEvent = {
        target: {
          name: target.name,
          checked: target.checked
        }
      };
      event.preventDefault( );
      dispatch( showAlert( msg, {
        title: I18n.t( "are_you_sure?" ),
        onConfirm: ( ) => {
          target.checked = confirmEvent.target.checked;
          dispatch( handleCheckboxChange( confirmEvent ) );
        }
      } ) );
    },
    showModalDescription: ( description, options = { } ) => dispatch(
      showAlert( description, { title: options.title || I18n.t( "about" ) } )
    )
  };
}

const CheckboxRowContainer = connect(
  mapStateToProps,
  mapDispatchToProps
)( CheckboxRow );

export default CheckboxRowContainer;
