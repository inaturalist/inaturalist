import React from "react";
import PropTypes from "prop-types";
import ReactDOM from "react-dom";

class INatTextArea extends React.Component {
  componentDidMount( ) {
    const domNode = ReactDOM.findDOMNode( this );
    const { mentions } = this.props;
    if ( mentions ) {
      $( "textarea", domNode ).textcompleteUsers( );
    }
  }

  render( ) {
    const {
      elementKey,
      name,
      className,
      value
    } = this.props;
    return (
      <div
        className="form-group"
        key={elementKey}
      >
        <textarea
          name={name}
          className={className}
          value={value}
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
