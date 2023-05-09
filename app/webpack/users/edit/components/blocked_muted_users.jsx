import React, { Component } from "react";
import PropTypes from "prop-types";
import ReactDOM from "react-dom";

import SettingsItem from "./settings_item";
import UserFollowing from "./user_following";
import UserAutocomplete from "../../../observations/identify/components/user_autocomplete";

class BlockedMutedUsers extends Component {
  handleSubmit( item ) {
    const { id, blockOrMute, showAlert } = this.props;
    showAlert(
      (
        <div>
          { id === "muted_users"
            ? I18n.t( "muting_description" )
            : I18n.t( "blocking_description" ) }
        </div>
      ), {
        title: I18n.t( "are_you_sure?" ),
        confirmText: id === "muted_users"
          ? I18n.t( "mute" )
          : I18n.t( "block" ),
        onConfirm: ( ) => {
          blockOrMute( item, id );
          this.inputElement( ).val( "" );
        }
      }
    );
  }

  inputElement( ) {
    const domNode = ReactDOM.findDOMNode( this );
    return $( "input[name='user_login']", domNode );
  }

  render( ) {
    const {
      mutedUsers,
      headerText,
      id,
      placeholder,
      buttonText,
      htmlDescription,
      unblockOrUnmute,
      blockedUsers
    } = this.props;

    const displayList = user => (
      <div className="row flex-no-wrap profile-photo-margin" key={user.id}>
        <div className="col-sm-6">
          <UserFollowing user={user} />
        </div>
        <div className="col-sm-6">
          <button
            type="button"
            className="btn btn-default"
            onClick={( ) => unblockOrUnmute( user.id, id )}
          >
            {buttonText}
          </button>
        </div>
      </div>
    );

    return (
      <div className="row BlockMutedUsers">
        <div className="col-md-12">
          <SettingsItem header={headerText} htmlFor={id}>
            <div className={`input-group ${blockedUsers.length === 3 && id === "blocked_users" && "hidden"}`}>
              <UserAutocomplete
                resetOnChange={false}
                afterSelect={( { item } ) => this.handleSubmit( item )}
                bootstrapClear
                placeholder={placeholder}
              />
            </div>
            {id === "muted_users"
              ? mutedUsers.map( user => displayList( user ) )
              : blockedUsers.map( user => displayList( user ) )}
          </SettingsItem>
          <p
            className="text-muted"
            // eslint-disable-next-line react/no-danger
            dangerouslySetInnerHTML={htmlDescription}
          />
        </div>
      </div>
    );
  }
}

BlockedMutedUsers.propTypes = {
  mutedUsers: PropTypes.array,
  headerText: PropTypes.string,
  id: PropTypes.string,
  placeholder: PropTypes.string,
  buttonText: PropTypes.string,
  htmlDescription: PropTypes.object,
  blockOrMute: PropTypes.func,
  unblockOrUnmute: PropTypes.func,
  blockedUsers: PropTypes.array,
  showAlert: PropTypes.func
};

export default BlockedMutedUsers;
