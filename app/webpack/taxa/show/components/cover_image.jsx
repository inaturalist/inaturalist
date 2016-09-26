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
    const img = new Image();
    img.src = p.src;
    const that = this;
    img.onload = function () {
      ReactDOM.findDOMNode( that ).classList.add( "loaded" );
      ReactDOM.findDOMNode( that ).style.backgroundImage = `url(${this.src})`;
    };
  }
  render( ) {
    const lowResUrl = this.props.low || this.props.src;
    return (
      <div
        className={`CoverImage ${this.props.className}`}
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
