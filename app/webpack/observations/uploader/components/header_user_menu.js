import React, { PropTypes, Component } from "react";

class HeaderUserMenu extends Component {

  render( ) {
    const user = this.props.user;
    return (
      <div className="navbar-collapse collapse" aria-expanded="false">
        <ul className="nav navbar-nav navbar-right">
          <li className="dropdown">
            <a
              href="#"
              className="dropdown-toggle dropdown-profile"
              data-toggle="dropdown"
              role="button"
              aria-haspopup="true"
              aria-expanded="false"
            >
              <img src={ user.icon } className="img-circle profile-pic" />
              { user.login }
              <span className="caret"></span>
            </a>
            <ul className="dropdown-menu">
              <li><a href="/home">Dashboard</a></li>
              <li><a href={ `/observations/${user.login}` }>Observations</a></li>
              <li><a href="/observations/add">&nbsp;↳ Add</a></li>
              <li><a href="/observations/import">&nbsp;↳ Import</a></li>
              <li><a href={ `/calendar/${user.login}` }>&nbsp;↳ Calendar</a></li>
              <li><a href={ `/faves/${user.login}` }>Favorites</a></li>
              <li><a href={ `/lists/${user.login}` }>Lists</a></li>
              <li><a href={ `/journals/${user.login}` }>Journal</a></li>
              <li><a href="messages">Messages</a></li>
              <li><a href={ `/${user.login}` }>Profile</a></li>
              <li><a href={ `/${user.login}/edit` }>Account</a></li>
              <li role="separator" className="divider"></li>
              <li><a href="/logout">Sign Out</a></li>
            </ul>
          </li>
        </ul>
      </div>
    );
  }
}

HeaderUserMenu.propTypes = {
  user: PropTypes.object
};

export default HeaderUserMenu;
