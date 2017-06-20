import _ from "lodash";
import React, { PropTypes } from "react";
import ReactDOM from "react-dom";

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
    let glyph = "fa-exclamation-triangle";
    let alertClass = this.props.type || "warning";
    if ( alertClass === "flag" ) {
      alertClass = "danger";
      glyph = "fa-flag";
    } else if ( alertClass === "success" ) {
      glyph = "fa-check-circle";
    } else if ( alertClass === "danger" ) {
      glyph = "fa-times-circle";
    }
    const title = this.props.title ?
      ( <span className="bold">{ this.props.title }.</span> ) : "";
    return (
      <div className="FlashMessage container">
        <div className={ `alert alert-${alertClass}` }>
          <div className="message">
            <i className={ `fa ${glyph}` } />
            { title }
            { _.isString( this.props.message ) ?
              ( <span dangerouslySetInnerHTML={ { __html: this.props.message } } /> ) :
              this.props.message
            }
          </div>
          <div className="action">
            <i className="fa fa-times-circle-o" onClick={ this.close } />
          </div>
        </div>
      </div>
    );
  }
}

FlashMessage.propTypes = {
  type: PropTypes.string,
  message: PropTypes.any,
  title: PropTypes.string
};

export default FlashMessage;
