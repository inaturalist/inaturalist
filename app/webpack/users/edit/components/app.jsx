import React, { Component } from "react";

import Menu from "./menu";
import AccountContainer from "../containers/account_container";
import ContentContainer from "../containers/content_container";
import ProfileContainer from "../containers/profile_container";
import NotificationsContainer from "../containers/notifications_container";
import SaveButtonContainer from "../containers/save_button_container";
// import SaveReminderModal from "./save_reminder_modal";
import ApplicationsContainer from "../containers/applications_container";
import RevokeAccessModalContainer from "../containers/revoke_access_modal_container";


class App extends Component {
  constructor( ) {
    super( );

    this.state = {
      container: 0
      // showModal: false
    };

    this.setContainerIndex = this.setContainerIndex.bind( this );
  }

  setContainerIndex( i ) {
    this.setState( { container: i } );
  }

  render( ) {
    const { container } = this.state;

    const userSettings = [
      <ProfileContainer />,
      <AccountContainer />,
      <NotificationsContainer />,
      <></>,
      <ContentContainer />,
      <ApplicationsContainer />
    ];

    return (
      <div className="container">
        {/* <SaveReminderModal showModal={this.state.showModal} /> */}
        <div className="row">
          <div className="col-sm-9">
            <h1>{I18n.t( "settings" )}</h1>
          </div>
          <div className="col-sm-3">
            <SaveButtonContainer />
          </div>
        </div>
        <div className="row">
          <div className="col-xs-2 menu">
            <Menu setContainerIndex={this.setContainerIndex} />
          </div>
          <div className="col-xs-1">
            <div className="vl" />
          </div>
          {userSettings[container]}
        </div>
        <RevokeAccessModalContainer />
      </div>
    );
  }
}

export default App;
