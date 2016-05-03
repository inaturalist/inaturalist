import React, { PropTypes, Component } from "react";
import { Glyphicon, MenuItem,
  Navbar, Nav, NavDropdown, NavItem } from "react-bootstrap";

class TopMenu extends Component {

  render( ) {
    const { createBlankObsCard, confirmRemoveSelected, selectAll, combineSelected,
      trySubmitObservations, fileChooser, countTotal, countSelected, selectNone,
      countSelectedPending, countPending } = this.props;
    let saveButton;
    if ( countTotal > 0 ) {
      saveButton = (
        <button
          type="button"
          onClick={ trySubmitObservations }
          disabled={ countPending > 0 || countTotal === 0 }
          className="btn btn-success navbar-btn"
        >
          Submit{ countTotal > 0 ? ` ${countTotal} observation${countTotal > 1 ? "s" : ""}` : "" }
        </button>
      );
    }
    let dropdownToggle = (
      <div>
        <Glyphicon glyph="plus" />
        Add
      </div>
    );
    return (
      <Navbar className="nav_add_obs" fluid>
        <Nav>
          <NavDropdown title={ dropdownToggle } id="add_photos">
            <MenuItem onClick={ fileChooser }>Photo(s)</MenuItem>
            <MenuItem onClick={ createBlankObsCard }>Observation without photo</MenuItem>
          </NavDropdown>
          <NavItem
            onClick={ confirmRemoveSelected }
            disabled={ countSelected === 0 }
          >
            <Glyphicon glyph="remove" />
            Remove
          </NavItem>
          <NavItem
            onClick={ combineSelected }
            disabled={ countSelectedPending > 0 || countSelected < 2 }
          >
            <Glyphicon glyph="resize-small" />
            Combine
          </NavItem>
          <li className={ `select ${countTotal === 0 && "disabled"}` }>
            <form className="navbar-form" role="search">
              <input
                type="checkbox"
                key={ `select${countSelected}${countTotal}` }
                disabled={ countTotal === 0 }
                checked={ countTotal > 0 && countSelected === countTotal }
                onChange={ ( ) => ( countSelected !== countTotal ? selectAll( ) : selectNone( ) ) }
              />
              Select All
            </form>
          </li>
        </Nav>
        <Nav pullRight>
          { saveButton }
        </Nav>
      </Navbar>
    );
  }
}

TopMenu.propTypes = {
  createBlankObsCard: PropTypes.func,
  confirmRemoveSelected: PropTypes.func,
  selectAll: PropTypes.func,
  selectNone: PropTypes.func,
  selectedObsCards: PropTypes.object,
  trySubmitObservations: PropTypes.func,
  combineSelected: PropTypes.func,
  fileChooser: PropTypes.func,
  countTotal: PropTypes.number,
  countSelected: PropTypes.number,
  countSelectedPending: PropTypes.number,
  countPending: PropTypes.number
};

export default TopMenu;
