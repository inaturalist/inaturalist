import React from "react";

const menuItems = ["Profile & User", "Account", "Notifications", "Relationships", "Content & Display", "Applications"];

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
