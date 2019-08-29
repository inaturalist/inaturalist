import React from "react";
import PropTypes from "prop-types";
import ReactDOM from "react-dom";
import OnScreen from "onscreen";
import _ from "lodash";

class CoverImage extends React.Component {
  static idForUrl( url ) {
    return `cover-image-${_.kebabCase( url )}`;
  }

  constructor( ) {
    super( );
    this.state = {
      loaded: false
    };
  }

  componentDidMount( ) {
    // TODO: find a better way to do this
    // there is an async domNode.classList.add below which fails if this component is
    // unmounts before the async finishes - cannot add classes to unmounted components
    this.mounted = true;
    this.loadOrDelayImages( );
  }

  componentWillReceiveProps( newProps ) {
    const { src } = this.props;
    if ( src !== newProps.src ) {
      this.setState( { loaded: false } );
      this.loadOrDelayImages( newProps, { force: true } );
    }
  }

  componentWillUnmount( ) {
    this.mounted = false;
  }

  loadOrDelayImages( props, options = {} ) {
    const domNode = ReactDOM.findDOMNode( this );
    const p = props || this.props;
    const that = this;
    if ( p.lazyLoad ) {
      const os = new OnScreen( );
      const selector = `#${CoverImage.idForUrl( p.src )}`;
      os.on( "enter", selector, ( ) => {
        if ( options.force || !that.state.loaded ) {
          this.loadImages( p, domNode, options );
        }
        os.off( "enter", selector );
      } );
      return;
    }
    this.loadImages( p, domNode, options );
  }

  loadImages( props, domNode, options = {} ) {
    const p = props || this.props;
    const { loaded } = this.state;
    if ( loaded && !options.force ) {
      return;
    }
    if ( p.low ) {
      domNode.style.backgroundImage = `url(${p.low})`;
      const img = new Image( );
      img.src = p.src;
      img.onload = ( ) => {
        if ( this.mounted ) {
          domNode.classList.add( "loaded" );
          this.setState( { loaded: true } );
          domNode.style.backgroundImage = `url("${img.src}")`;
        }
      };
    } else if ( this.mounted ) {
      domNode.classList.add( "loaded" );
      this.setState( { loaded: true } );
      domNode.style.backgroundImage = `url("${p.src}")`;
    }
  }

  render( ) {
    const {
      low,
      src,
      className,
      height,
      backgroundSize,
      backgroundPosition
    } = this.props;
    const lowResUrl = low || src;
    return (
      <div
        id={CoverImage.idForUrl( src )}
        className={`CoverImage low ${className}`}
        style={{
          width: "100%",
          minHeight: height,
          backgroundSize,
          backgroundPosition,
          backgroundRepeat: "no-repeat",
          backgroundImage: `url('${lowResUrl}')`
        }}
      />
    );
  }
}

CoverImage.propTypes = {
  src: PropTypes.string.isRequired,
  low: PropTypes.string,
  height: PropTypes.number.isRequired,
  className: PropTypes.string,
  lazyLoad: PropTypes.bool,
  backgroundSize: PropTypes.string,
  backgroundPosition: PropTypes.string
};

CoverImage.defaultProps = {
  backgroundSize: "cover",
  backgroundPosition: "center"
};

export default CoverImage;
