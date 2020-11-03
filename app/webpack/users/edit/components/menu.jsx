import React from "react";
import PropTypes from "prop-types";

const menuItems = [
  I18n.t( "profile_and_user" ),
  I18n.t( "account" ),
  I18n.t( "notifications" ),
  I18n.t( "relationships_user_settings" ),
  I18n.t( "content_and_display" ),
  I18n.t( "applications" )
];

const Menu = ( { menuIndex, setContainerIndex } ) => menuItems.map( ( item, i ) => (
  <div key={item}>
    <button
      type="button"
      name={i}
      id="LeftNav"
      className={`left-nav-item ${menuIndex && "green"}`}
      onClick={( ) => setContainerIndex( i )}
    >
      {item}
    </button>
  </div>
) );

Menu.propTypes = {
  setContainerIndex: PropTypes.func,
  menuIndex: PropTypes.number
};

export default Menu;
