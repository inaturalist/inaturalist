import _ from "lodash";
import React from "react";
import PropTypes from "prop-types";
import ReactDOM from "react-dom";
import UserText from "../../../shared/components/user_text";

class FlashMessage extends React.Component {
  constructor( ) {
    super( );
    this.close = this.close.bind( this );
  }

  componentDidMount( ) {
    if ( this.props.type === "success" ) {
      setTimeout( ( ) => {
        $( ReactDOM.findDOMNode( this ) ).fadeOut( 1000 );
      }, 5000 );
    }
  }

  close( ) {
    $( ReactDOM.findDOMNode( this ) ).fadeOut( 500 );
  }

  render( ) {
    const {
      html,
      message,
      title,
      type
    } = this.props;
    let glyph = "fa-exclamation-triangle";
    let alertClass = type || "warning";
    if ( alertClass === "flag" ) {
      alertClass = "danger";
      glyph = "fa-flag";
    } else if ( alertClass === "success" ) {
      glyph = "fa-check-circle";
    } else if ( alertClass === "error" ) {
      alertClass = "danger";
      glyph = "fa-times-circle";
    }
    const titleElt = title
      ? (
        <span className="bold">
          { `${title}.` }
        </span>
      )
      : "";
    const messageElt = html
      ? <UserText text={message} />
      : <span dangerouslySetInnerHTML={{ __html: message }} />;
    return (
      <div className="FlashMessage container">
        <div className={`alert alert-${alertClass}`}>
          <div className="message">
            <i className={`fa ${glyph}`} />
            { titleElt }
            { _.isString( message ) ? messageElt : message }
          </div>
          <button
            type="button"
            className="btn btn-nostyle action"
            onClick={this.close}
          >
            <i className="fa fa-times-circle-o" />
          </button>
        </div>
      </div>
    );
  }
}

FlashMessage.propTypes = {
  type: PropTypes.string,
  message: PropTypes.any,
  title: PropTypes.string,
  html: PropTypes.bool
};

export default FlashMessage;
