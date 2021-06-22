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

const Menu = ( { currentContainer, setContainerIndex } ) => menuItems.map( ( item, i ) => (
  <div key={item}>
    <button
      type="button"
      name={i}
      id="LeftNav"
      className={`left-nav-item ${currentContainer === i && "selected"}`}
      onClick={( ) => setContainerIndex( i )}
    >
      {item}
    </button>
  </div>
) );

Menu.propTypes = {
  setContainerIndex: PropTypes.func,
  currentContainer: PropTypes.number
};

export default Menu;
