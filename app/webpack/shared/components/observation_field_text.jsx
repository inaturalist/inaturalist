import React, { PropTypes } from "react";

class ObservationFieldText extends React.Component {
  render( ) {
    const text = this.props.text;
    const isLink = /https?:\/\//.test( text );
    const LinkElement = ( isLink ) ? "a" : "span";

    return (
       <LinkElement href={text}>{text}</LinkElement>
    );
  }
}

ObservationFieldText.propTypes = {
  text: PropTypes.string
};

export default ObservationFieldText;
