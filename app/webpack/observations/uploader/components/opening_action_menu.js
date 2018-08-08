import React, { Component } from "react";
import PropTypes from "prop-types";
import { Button, DropdownButton, Glyphicon, MenuItem } from "react-bootstrap";

class OpeningActionMenu extends Component {

  render( ) {
    return (
      <div className="intro">
        <div className="start">
          <div className="drag_or_choose">
            <h1>{ I18n.t( "drag_and_drop_some_photos_or_sounds" ) }</h1>
            <p>{ I18n.t( "or" ) }</p>
            <Button bsStyle="primary" bsSize="large" onClick={ this.props.fileChooser }>
              { I18n.t( "choose_files" ) }
              <Glyphicon glyph="upload" />
            </Button>
          </div>
          <DropdownButton
            bsStyle="default"
            title={ I18n.t( "more_import_options" ) }
            id="more_imports"
          >
            <MenuItem href="/observations/import#photo_import">
              { I18n.t( "from_flickr_facebook_etc" ) }
            </MenuItem>
            <MenuItem href="/observations/import#sound_import">
              { I18n.t( "from_soundcloud" ) }
            </MenuItem>
            <MenuItem divider />
            <MenuItem href="/observations/import#csv_import">
              { I18n.t( "csv" ) }
            </MenuItem>
            <MenuItem href="/observations/new">
              { I18n.t( "old_observation_form" ) }
            </MenuItem>
          </DropdownButton>
        </div>
        <div className="hover">
          <p>{ I18n.t( "drop_it" ) }</p>
        </div>
      </div>
    );
  }
}

OpeningActionMenu.propTypes = {
  fileChooser: PropTypes.func
};

export default OpeningActionMenu;
