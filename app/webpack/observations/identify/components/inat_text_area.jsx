import React from "react";
import PropTypes from "prop-types";
import ReactDOM from "react-dom";

class INatTextArea extends React.Component {
  componentDidMount( ) {
    const domNode = ReactDOM.findDOMNode( this );
    if ( this.props.mentions ) {
      $( "textarea", domNode ).textcompleteUsers( );
    }
  }

  render( ) {
    return (
      <div
        className="form-group"
        key={ this.props.elementKey }
      >
        <textarea
          name={this.props.name}
          className={this.props.className}
          value={this.props.value}
        />
      </div>
    );
  }
}

INatTextArea.propTypes = {
  className: PropTypes.string,
  name: PropTypes.string,
  mentions: PropTypes.bool,
  value: PropTypes.string,
  elementKey: PropTypes.string
};

export default INatTextArea;
