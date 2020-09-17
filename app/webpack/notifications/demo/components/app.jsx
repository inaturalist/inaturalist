import _ from "lodash";
import React from "react";
import PropTypes from "prop-types";
import moment from "moment-timezone";

class App extends React.Component {
  // eslint-disable-next-line class-methods-use-this
  renderType( readState, type ) {
    let icon;
    switch ( type ) {
      case "mention":
        icon = "at";
        break;
      case "comment":
        icon = "commenting-o";
        break;
      case "flag":
        icon = "flag";
        break;
      case "fave":
        icon = "star-o";
        break;
      default:
        break;
    }
    return icon ? ( <span className={`type ${type} fa fa-${icon} ${readState}`} /> ) : null;
  }

  renderNotification( notification ) {
    let icon;
    if ( notification.resource.icon ) {
      icon = ( <img src={notification.resource.icon} /> );
    } else {
      icon = notification.resource.type[0];
    }
    return (
      <div className={`notification ${notification.read_state}`} key={notification.id}>
        <a href={notification.url}>
          <div className="icon">
            { icon }
          </div>
        </a>
        <div className="body">
          <div className="statement">
            { notification.statement}
            <br />
            Notification::
            { notification.id }
          </div>
          <div className="summary">
            <div className="types">
              { _.map( notification.types, this.renderType ) }
            </div>
            <div className="date">
              { moment.tz( notification.date, moment.tz.guess( ) ).format( "MMM D, YYYY · LTS" ) }
            </div>
          </div>
        </div>
        <div className={`read-indicator ${notification.read_state}`}>
          <a href={`/notifications/${notification.id}/mark_as_${notification.read_state === "read" ? "unread" : "read"}`}>
            { notification.read_state === "read"
              ? ( <span className="fa fa-circle-thin" /> )
              : ( <span className="fa fa-circle" /> )
            }
          </a>
        </div>
      </div>
    );
  }

  render( ) {
    const {
      apiResponse
    } = this.props;
    return (
      <div id="NotificationsDemo" className="container">
        <div className="categories">
          <a href="?category=conversations">
            <button type="button">Conversations ({apiResponse.category_counts.conversations || 0})</button>
          </a>
          <a href="?category=my_observations">
            <button type="button">My Observations ({apiResponse.category_counts.my_observations || 0})</button>
          </a>
          <a href="?category=others_observations">
            <button type="button">Others&apos; Observations ({apiResponse.category_counts.others_observations || 0})</button>
          </a>
          <a href="?category=other">
            <button type="button">Other ({apiResponse.category_counts.other || 0})</button>
          </a>
        </div>
        <div className="notifications">
          { _.map( apiResponse.notifications, n => this.renderNotification( n ) ) }
        </div>
      </div>
    );
  }
}

App.propTypes = {
  apiResponse: PropTypes.object
};

export default App;
