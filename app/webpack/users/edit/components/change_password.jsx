import React, { Component } from "react";

class ChangePassword extends Component {
  constructor( ) {
    super( );

    this.state = {
      showPasswordForm: false
    };
  }

  render( ) {
    const { showPasswordForm } = this.state;

    return (
      <div className="settings-item">
        {/* Change this into a button since using onClick? */}
        <label
          className="inverse-toggle collapsible"
          htmlFor="user_password"
          onClick={( ) => {
            this.setState( { showPasswordForm: !showPasswordForm } );
          }}
        >
          {`${I18n.t( "change_password" )} `}
          <i className={`fa fa-caret-${showPasswordForm ? "down" : "right"}`} aria-hidden="true" />
        </label>
        <div className={showPasswordForm ? null : "collapse"}>
          <form id="user_password">
            <div className="form-group">
              <label>
                {I18n.t( "new_password" )}
                <input type="text" className="form-control" name="new_password" />
              </label>
            </div>
            <div className="form-group">
              <label>
                {I18n.t( "confirm_new_password" )}
                <input type="text" className="form-control" name="confirm_new_password" />
              </label>
            </div>
          </form>
          <button className="btn btn-xs btn-primary" type="button">
            {I18n.t( "change_password" )}
          </button>
        </div>
      </div>
    );
  }
}

export default ChangePassword;
