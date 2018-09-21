import _ from "lodash";
import React from "react";
import PropTypes from "prop-types";
import { Dropdown, MenuItem } from "react-bootstrap";

class FeatureButton extends React.Component {
  render( ) {
    const { config, project, feature, unfeature } = this.props;
    const loggedIn = config.currentUser;
    const userIsAdmin = loggedIn && config.currentUser.roles &&
      config.currentUser.roles.indexOf( "admin" ) >= 0;
    const userIsSiteAdmin = loggedIn && config.currentUser.site_admin;
    const siteFeature = _.find( project.site_features, sf => sf.site_id === config.site.id );
    if ( !userIsAdmin && !userIsSiteAdmin ) {
      return null;
    }
    let buttonLabel = I18n.t( "feature_this_project_" );
    let menuItems = [(
      <MenuItem
        key={ "noteworthy" }
        eventKey={ "noteworthy" }
        disabled={ siteFeature && siteFeature.noteworthy }
        className={ siteFeature && siteFeature.noteworthy ? "bold" : null }
      >
        { I18n.t( "new_and_noteworthy" ) }
      </MenuItem> ), (
      <MenuItem
        key={ "featured" }
        eventKey={ "featured" }
        disabled={ siteFeature && !siteFeature.noteworthy }
        className={ siteFeature && !siteFeature.noteworthy ? "bold" : null }
      >
        { I18n.t( "featured" ) }
      </MenuItem> )
    ];
    if ( siteFeature ) {
      buttonLabel = I18n.t( "featuring" ) + ": " + ( siteFeature.noteworthy ?
        I18n.t( "new_and_noteworthy" ) : I18n.t( "featured" ) );
      menuItems.push( (
        <MenuItem
          key={ "remove" }
          eventKey={ "remove" }
        >
          { I18n.t( "remove_from_featured" ) }
        </MenuItem>
      ) );
    }
    return (
      <Dropdown
        id="grouping-control"
        onSelect={ key => {
          if ( key === "remove" ) {
            unfeature( );
          } else {
            const params = { };
            if ( key === "noteworthy" ) {
              params.noteworthy = true;
            }
            feature( params );
          }
        } }
      >
        <Dropdown.Toggle>
          { buttonLabel }
        </Dropdown.Toggle>
        <Dropdown.Menu>
          { menuItems }
        </Dropdown.Menu>
      </Dropdown>
    );
  }
}

FeatureButton.propTypes = {
  config: PropTypes.object,
  project: PropTypes.object,
  feature: PropTypes.func,
  unfeature: PropTypes.func
};

export default FeatureButton;
