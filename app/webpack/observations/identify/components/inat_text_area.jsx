import React, { PropTypes } from "react";
import ReactDOM from "react-dom";
import { Input } from "react-bootstrap";

class INatTextArea extends React.Component {
  componentDidMount( ) {
    const domNode = ReactDOM.findDOMNode( this );
    if ( this.props.mentions ) {
      $( "textarea", domNode ).textcompleteUsers( );
    }
  }

  render( ) {
    return (
      <Input
        type="textarea"
        name={this.props.name}
        className={this.props.className}
        value={this.props.value}
      />
    );
  }
}

INatTextArea.propTypes = {
  className: PropTypes.string,
  name: PropTypes.string,
  mentions: PropTypes.bool,
  value: PropTypes.string
};

export default INatTextArea;
