import React from "react";
import PropTypes from "prop-types";

const menuItems = [
  I18n.t( "profile" ),
  I18n.t( "account" ),
  I18n.t( "notifications" ),
  I18n.t( "relationships_user_settings" ),
  I18n.t( "content_and_display" ),
  I18n.t( "applications" )
];

const DropdownMenuMobile = ( { handleInputChange, menuIndex } ) => (
  <select
    className="form-control btn mobile-menu"
    id="dropdown-menu-mobile"
    name="dropdown-menu-mobile"
    value={menuIndex}
    onChange={handleInputChange}
  >
    {menuItems.map( ( item, i ) => (
      <option value={i} key={item}>{item}</option>
    ) )}
  </select>
);

DropdownMenuMobile.propTypes = {
  handleInputChange: PropTypes.func,
  menuIndex: PropTypes.number
};

export default DropdownMenuMobile;
