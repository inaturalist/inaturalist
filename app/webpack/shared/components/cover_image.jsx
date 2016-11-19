import React, { PropTypes } from "react";
import ReactDOM from "react-dom";
import OnScreen from "onscreen";
import _ from "lodash";

class CoverImage extends React.Component {
  componentDidMount( ) {
    this.loadOrDelayImages( );
  }
  componentWillReceiveProps( newProps ) {
    this.loadOrDelayImages( newProps );
  }
  loadOrDelayImages( props ) {
    const p = props || this.props;
    if ( p.lazyLoad ) {
      const os = new OnScreen( );
      const selector = `#${this.idForUrl( p.src )}`;
      os.on( "enter", selector, element => {
        if ( !element.classList.contains( "loaded" ) ) {
          this.loadImages( p );
        }
        os.off( "enter", selector );
      } );
      return;
    }
    this.loadImages( p );
  }
  loadImages( props ) {
    const p = props || this.props;
    const domNode = ReactDOM.findDOMNode( this );
    if ( domNode.classList.contains( "loaded" ) ) {
      return;
    }
    if ( p.low && !domNode.classList.contains( "low-loaded" ) ) {
      const lowImage = new Image();
      lowImage.src = p.low;
      lowImage.onload = function ( ) {
        domNode.classList.add( "low-loaded" );
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
  idForUrl( url ) {
    return `cover-image-${_.kebabCase( url )}`;
  }
  render( ) {
    const lowResUrl = this.props.low || this.props.src;
    return (
      <div
        id={this.idForUrl( this.props.src )}
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
  className: PropTypes.string,
  lazyLoad: PropTypes.bool
};

export default CoverImage;
