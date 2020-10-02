import React from "react";

const menuItems = [
  I18n.t( "profile_and_user" ),
  I18n.t( "account" ),
  I18n.t( "notifications" ),
  I18n.t( "relationships_user_settings" ),
  I18n.t( "content_and_display" ),
  I18n.t( "applications" )
];

const Menu = () => (
  <div id="UserSettingsMenu">
    {menuItems.map( item => (
      <dl key={item}>
        <dt>
          <a href="#">{item}</a>
        </dt>
      </dl>
    ) )}
  </div>
);

export default Menu;
