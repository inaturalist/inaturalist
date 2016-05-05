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
              <li><a href="/home">{ I18n.t( "dashboard" ) }</a></li>
              <li><a href={ `/observations/${user.login}` }>{ I18n.t( "observations" ) }</a></li>
              <li><a href="/observations/new">&nbsp;↳ { I18n.t( "add" ) }</a></li>
              <li><a href="/observations/import">&nbsp;↳ { I18n.t( "import" ) }</a></li>
              <li><a href={ `/calendar/${user.login}` }>&nbsp;↳ { I18n.t( "calendar" ) }</a></li>
              <li><a href={ `/faves/${user.login}` }>{ I18n.t( "favorites" ) }</a></li>
              <li><a href={ `/lists/${user.login}` }>{ I18n.t( "lists" ) }</a></li>
              <li><a href={ `/journal/${user.login}` }>{ I18n.t( "journal" ) }</a></li>
              <li><a href="/messages">{ I18n.t( "messages" ) }</a></li>
              <li><a href={ `/people/${user.login}` }>{ I18n.t( "profile" ) }</a></li>
              <li><a href={ `/people/${user.login}/edit` }>{ I18n.t( "account" ) }</a></li>
              <li role="separator" className="divider"></li>
              <li><a href="/logout">{ I18n.t( "sign_out" ) }</a></li>
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
