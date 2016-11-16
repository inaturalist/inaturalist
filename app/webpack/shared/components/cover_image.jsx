import React, { PropTypes } from "react";
import ReactDOM from "react-dom";

class CoverImage extends React.Component {
  componentDidMount( ) {
    this.loadImages( );
  }
  componentWillReceiveProps( newProps ) {
    this.loadImages( newProps );
  }
  loadImages( props ) {
    const p = props || this.props;
    const domNode = ReactDOM.findDOMNode( this );
    if ( p.low ) {
      const lowImage = new Image();
      lowImage.src = p.low;
      lowImage.onload = function ( ) {
        domNode.classList.add( "loaded" );
        domNode.style.backgroundImage = `url(${this.src})`;
      };
    }
    const img = new Image();
    img.src = p.src;
    img.onload = function ( ) {
      domNode.classList.add( "loaded" );
      domNode.style.backgroundImage = `url(${this.src})`;
    };
  }
  render( ) {
    const lowResUrl = this.props.low || this.props.src;
    return (
      <div
        className={`CoverImage low ${this.props.className}`}
        style={{
          width: "100%",
          minHeight: this.props.height,
          backgroundSize: "cover",
          backgroundPosition: "center",
          backgroundImage: `url(${lowResUrl})`
        }}
      >
      </div>
    );
  }
}

CoverImage.propTypes = {
  src: PropTypes.string.isRequired,
  low: PropTypes.string,
  height: PropTypes.number.isRequired,
  className: PropTypes.string
};

export default CoverImage;
