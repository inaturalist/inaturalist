import React, { Component } from "react";
import PropTypes from "prop-types";
import { Glyphicon, MenuItem, OverlayTrigger, Tooltip,
  Navbar, Nav, NavDropdown, NavItem } from "react-bootstrap";

class TopMenu extends Component {

  render( ) {
    const { createBlankObsCard, confirmRemoveSelected, selectAll, combineSelected,
      trySubmitObservations, fileChooser, countTotal, countSelected, selectNone } = this.props;
    let saveButton;
    if ( countTotal > 0 ) {
      saveButton = (
        <button
          type="button"
          onClick={ trySubmitObservations }
          className="btn btn-success navbar-btn"
        >
          { I18n.t( "submit_observations", { count: countTotal } ) }
        </button>
      );
    }
    let dropdownToggle = (
      <div>
        <Glyphicon glyph="plus" />
        { I18n.t( "add" ) }
      </div>
    );
    let className = "nav_add_obs";
    if ( this.props.scrolledPastToolbar ) { className += " fixed"; }
    const removeDisabled = countSelected === 0;
    const combineDisabled = countSelected < 2;
    const selectAllDisabled = countTotal === 0;
    return (
      <Navbar className={ className } fluid>
        <Nav>
          <OverlayTrigger
            placement="top"
            delayShow={ 1000 }
            overlay={ ( <Tooltip id="add-tip">{ I18n.t( "uploader.tooltips.add" ) }</Tooltip> ) }
          >
            <NavDropdown title={ dropdownToggle } id="add_photos">
              <MenuItem onClick={ fileChooser }>{ I18n.t( "photos_or_sounds" ) }</MenuItem>
              <MenuItem onClick={ createBlankObsCard }>
                { I18n.t( "observation_without_media" ) }
              </MenuItem>
            </NavDropdown>
          </OverlayTrigger>
          <OverlayTrigger
            placement="top"
            delayShow={ 1000 }
            overlay={ removeDisabled ? ( <span /> ) :
              ( <Tooltip id="remove-tip">{ I18n.t( "uploader.tooltips.remove" ) }</Tooltip> ) }
          >
            <NavItem
              onClick={ confirmRemoveSelected }
              disabled={ removeDisabled }
            >
              <Glyphicon glyph="remove" />
              { I18n.t( "remove" ) }
            </NavItem>
          </OverlayTrigger>
          <OverlayTrigger
            placement="top"
            delayShow={ 1000 }
            overlay={ combineDisabled ? ( <span /> ) :
              ( <Tooltip id="merge-tip">{ I18n.t( "uploader.tooltips.combine" ) }</Tooltip> ) }
          >
            <NavItem
              onClick={ combineSelected }
              disabled={ combineDisabled }
            >
              <Glyphicon glyph="resize-small" />
              { I18n.t( "combine" ) }
            </NavItem>
          </OverlayTrigger>
          <OverlayTrigger
            placement="top"
            delayShow={ 1000 }
            overlay={ selectAllDisabled ? ( <span /> ) :
              ( <Tooltip id="select-tip">{ I18n.t( "uploader.tooltips.select_all" ) }</Tooltip> ) }
          >
            <li className={ `select ${countTotal === 0 && "disabled"}` }>
              <form className="navbar-form" role="search">
                <input
                  id="select-all"
                  type="checkbox"
                  key={ `select${countSelected}${countTotal}` }
                  disabled={ selectAllDisabled }
                  checked={ countTotal > 0 && countSelected === countTotal }
                  onChange={ ( ) => (
                    countSelected !== countTotal ? selectAll( ) : selectNone( ) ) }
                />
                <label htmlFor="select-all">{ I18n.t( "select_all" ) }</label>
              </form>
            </li>
          </OverlayTrigger>
        </Nav>
        <div className="pull-right">
          { saveButton }
        </div>
      </Navbar>
    );
  }
}

TopMenu.propTypes = {
  combineSelected: PropTypes.func,
  confirmRemoveSelected: PropTypes.func,
  countPending: PropTypes.number,
  countSelected: PropTypes.number,
  countTotal: PropTypes.number,
  createBlankObsCard: PropTypes.func,
  fileChooser: PropTypes.func,
  reactKey: PropTypes.string,
  scrolledPastToolbar: PropTypes.bool,
  selectAll: PropTypes.func,
  selectedObsCards: PropTypes.object,
  selectNone: PropTypes.func,
  trySubmitObservations: PropTypes.func
};

export default TopMenu;
