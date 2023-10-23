import React from "react";
import PropTypes from "prop-types";
import {
  Glyphicon,
  MenuItem,
  OverlayTrigger,
  Tooltip,
  Navbar,
  Nav,
  NavDropdown,
  NavItem
} from "react-bootstrap";

const TopMenu = ( {
  createBlankObsCard,
  confirmRemoveSelected,
  selectAll,
  combineSelected,
  duplicateSelected,
  trySubmitObservations,
  fileChooser,
  countTotal,
  countSelected,
  selectNone,
  scrolledPastToolbar
} ) => {
  let saveButton;
  if ( countTotal > 0 ) {
    saveButton = (
      <button
        type="button"
        onClick={trySubmitObservations}
        className="btn btn-success navbar-btn"
      >
        { I18n.t( "submit_observations", { count: countTotal } ) }
      </button>
    );
  }
  const dropdownToggle = (
    <div>
      <Glyphicon glyph="plus" />
      { I18n.t( "add" ) }
    </div>
  );
  let className = "nav_add_obs";
  if ( scrolledPastToolbar ) { className += " fixed"; }
  const removeDisabled = countSelected === 0;
  const combineDisabled = countSelected < 2;
  const duplicateDisabled = countSelected === 0;
  const selectAllDisabled = countTotal === 0;
  return (
    <Navbar className={className} fluid>
      <Nav>
        <OverlayTrigger
          placement="top"
          delayShow={1000}
          overlay={( <Tooltip id="add-tip">{ I18n.t( "uploader.tooltips.add" ) }</Tooltip> )}
        >
          <NavDropdown title={dropdownToggle} id="add_photos">
            <MenuItem onClick={fileChooser}>{ I18n.t( "photos_or_sounds" ) }</MenuItem>
            <MenuItem onClick={createBlankObsCard}>
              { I18n.t( "observation_without_media" ) }
            </MenuItem>
          </NavDropdown>
        </OverlayTrigger>
        <OverlayTrigger
          placement="top"
          delayShow={1000}
          overlay={
            removeDisabled
              ? <span />
              : <Tooltip id="remove-tip">{ I18n.t( "uploader.tooltips.remove" ) }</Tooltip>
          }
        >
          <NavItem
            onClick={confirmRemoveSelected}
            disabled={removeDisabled}
          >
            <Glyphicon glyph="remove" />
            { I18n.t( "remove" ) }
          </NavItem>
        </OverlayTrigger>
        <OverlayTrigger
          placement="top"
          delayShow={1000}
          overlay={
            combineDisabled
              ? <span />
              : <Tooltip id="merge-tip">{ I18n.t( "uploader.tooltips.combine" ) }</Tooltip>
          }
        >
          <button
            type="button"
            className="btn btn-primary navbar-btn"
            onClick={combineSelected}
            disabled={combineDisabled}
          >
            <Glyphicon glyph="resize-small" />
            { I18n.t( "combine" ) }
          </button>
        </OverlayTrigger>
        <OverlayTrigger
          placement="top"
          delayShow={1000}
          overlay={
            duplicateDisabled
              ? <span />
              : <Tooltip id="duplicate-tip">{ I18n.t( "uploader.tooltips.duplicate" ) }</Tooltip>
          }
        >
          <button
            type="button"
            className="btn btn-primary navbar-btn"
            onClick={duplicateSelected}
            disabled={duplicateDisabled}
          >
            <i className="fa fa-files-o" />
            { " " }
            { I18n.t( "duplicate_verb" ) }
          </button>
        </OverlayTrigger>
        <OverlayTrigger
          placement="top"
          delayShow={1000}
          overlay={
            selectAllDisabled
              ? <span />
              : <Tooltip id="select-tip">{ I18n.t( "uploader.tooltips.select_all" ) }</Tooltip>
          }
        >
          <li className={`select ${countTotal === 0 && "disabled"}`}>
            <form className="navbar-form" role="search">
              <input
                id="select-all"
                type="checkbox"
                key={`select${countSelected}${countTotal}`}
                disabled={selectAllDisabled}
                checked={countTotal > 0 && countSelected === countTotal}
                onChange={
                  ( ) => ( countSelected !== countTotal ? selectAll( ) : selectNone( ) )
                }
              />
              <label htmlFor="select-all">{ I18n.t( "select_all" ) }</label>
            </form>
          </li>
        </OverlayTrigger>
      </Nav>
      { saveButton }
    </Navbar>
  );
};

TopMenu.propTypes = {
  combineSelected: PropTypes.func,
  confirmRemoveSelected: PropTypes.func,
  countSelected: PropTypes.number,
  countTotal: PropTypes.number,
  createBlankObsCard: PropTypes.func,
  duplicateSelected: PropTypes.func,
  fileChooser: PropTypes.func,
  scrolledPastToolbar: PropTypes.bool,
  selectAll: PropTypes.func,
  selectNone: PropTypes.func,
  trySubmitObservations: PropTypes.func
};

export default TopMenu;
