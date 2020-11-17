import React, { Component } from "react";
import PropTypes from "prop-types";

import Menu from "./menu";
import AccountContainer from "../containers/account_container";
import ContentContainer from "../containers/content_container";
import ProfileContainer from "../containers/profile_container";
import NotificationsContainer from "../containers/notifications_container";
import SaveButtonContainer from "../containers/save_button_container";
import ApplicationsContainer from "../containers/applications_container";
import RelationshipsContainer from "../containers/relationships_container";
import RevokeAccessModalContainer from "../containers/revoke_access_modal_container";
import ThirdPartyTrackingModalContainer from "../containers/third_party_tracking_modal_container";
import AboutLicensingModalContainer from "../containers/about_licensing_modal_container";
import DropdownMenuMobile from "./dropdown_menu_mobile";
import DeleteRelationshipModalContainer from "../containers/delete_relationship_modal_container";

class App extends Component {
  constructor( ) {
    super( );

    this.state = {
      container: 3
    };

    this.setContainerIndex = this.setContainerIndex.bind( this );
    this.handleUnload = this.handleUnload.bind( this );
    this.handleInputChange = this.handleInputChange.bind( this );
  }

  componentDidMount() {
    window.addEventListener( "beforeunload", this.handleUnload );
  }

  componentWillUnmount() {
    window.removeEventListener( "beforeunload", this.handleUnload );
  }

  setContainerIndex( i ) {
    this.setState( { container: i } );
  }

  handleUnload( e ) {
    const { profile } = this.props;
    e.preventDefault( );

    if ( profile.saved_status === "unsaved" ) {
      // Chrome requires returnValue to be set
      e.returnValue = "";
    } else {
      delete e.returnValue;
    }
  }

  handleInputChange( e ) {
    this.setState( { container: Number( e.target.value ) } );
  }

  render( ) {
    const { container } = this.state;

    const userSettings = [
      <ProfileContainer />,
      <AccountContainer />,
      <NotificationsContainer />,
      <RelationshipsContainer />,
      <ContentContainer />,
      <ApplicationsContainer />
    ];

    return (
      <div className="container">
        <div className="row">
          <div className="col-sm-9">
            <h1>{I18n.t( "settings" )}</h1>
          </div>
          <div className="col-xs-4 visible-xs settings-item">
            <DropdownMenuMobile menuIndex={container} handleInputChange={this.handleInputChange} />
          </div>
          <div className="col-xs-9 col-sm-3 settings-item">
            <SaveButtonContainer />
          </div>
        </div>
        <div className="row">
          <div className="col-xs-2 menu hidden-xs">
            <Menu setContainerIndex={this.setContainerIndex} />
          </div>
          <div className="col-xs-1 hidden-xs">
            <div className="vl" />
          </div>
          <div className="col-xs-9">
            {userSettings[container]}
          </div>
        </div>
        <RevokeAccessModalContainer />
        <ThirdPartyTrackingModalContainer />
        <AboutLicensingModalContainer />
        <DeleteRelationshipModalContainer />
      </div>
    );
  }
}

App.propTypes = {
  profile: PropTypes.object
};

export default App;
