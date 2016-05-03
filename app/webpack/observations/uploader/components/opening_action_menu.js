import React, { PropTypes, Component } from "react";
import { Button, DropdownButton, Glyphicon, MenuItem } from "react-bootstrap";

class OpeningActionMenu extends Component {

  render( ) {
    return (
      <div className="intro">
        <div className="start">
          <div className="drag_or_choose">
            <p>Drag and drop some photos</p>
            <p>or</p>
            <Button bsStyle="primary" bsSize="large" onClick={ this.props.fileChooser }>
              Choose photos
              <Glyphicon glyph="upload" />
            </Button>
          </div>
          <DropdownButton bsStyle="default" title="More Import Options" id="more_imports">
            <MenuItem href="/observations/import#csv_import">CSV</MenuItem>
            <MenuItem href="/observations/import#photo_import">
              From Flickr, Facebook, etc.
            </MenuItem>
            <MenuItem divider />
            <MenuItem header>Import Sounds</MenuItem>
            <MenuItem href="/observations/import#sound_import">From SoundCloud</MenuItem>
          </DropdownButton>
        </div>
        <div className="hover">
          <p>Drop it</p>
        </div>
      </div>
    );
  }
}

OpeningActionMenu.propTypes = {
  fileChooser: PropTypes.func
};

export default OpeningActionMenu;
