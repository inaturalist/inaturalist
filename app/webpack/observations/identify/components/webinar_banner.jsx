import React from "react";
import PropTypes from "prop-types";
import ReactDOM from "react-dom";

class WebinarBanner extends React.Component {
  close( ) {
    const { hideBanner } = this.props;
    $( ReactDOM.findDOMNode( this ) ).fadeOut( 500 );
    setTimeout( hideBanner, 500 );
  }

  render( ) {
    const { config } = this.props;
    if ( config.currentUser?.prefers_hide_identify_webinar_banner ) {
      return null;
    }
    return (
      <div className="WebinarBanner container">
        <div className="alert alert-success">
          <a
            href="https://www.inaturalist.org/blog/119680-identifying-on-inaturalist-how-you-can-help"
            className="message-link"
          >
            <div className="message">
              { I18n.t( "views.observations.identify.learn_how_to_use_this_page" ) }
            </div>
          </a>
          <div className="dismiss">
            <button
              type="button"
              label={I18n.t( "close" )}
              className="btn btn-nostyle action"
              onClick={this.close.bind( this )}
            >
              <i className="fa fa-times-circle-o" />
            </button>
          </div>
        </div>
      </div>
    );
  }
}

WebinarBanner.propTypes = {
  config: PropTypes.object,
  hideBanner: PropTypes.func
};

export default WebinarBanner;
