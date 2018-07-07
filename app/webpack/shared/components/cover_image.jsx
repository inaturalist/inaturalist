import React from "react";
import PropTypes from "prop-types";
import ReactDOM from "react-dom";
import OnScreen from "onscreen";
import _ from "lodash";

class CoverImage extends React.Component {
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
    if ( this.props.src !== newProps.src ) {
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
      const selector = `#${this.idForUrl( p.src )}`;
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
    if ( this.state.loaded && !options.force ) {
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
          domNode.style.backgroundImage = `url(${img.src})`;
        }
      };
    } else {
      if ( this.mounted ) {
        domNode.classList.add( "loaded" );
        this.setState( { loaded: true } );
        domNode.style.backgroundImage = `url(${p.src})`;
      }
    }
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
          backgroundSize: this.props.backgroundSize,
          backgroundPosition: "center",
          backgroundRepeat: "no-repeat",
          backgroundImage: `url('${lowResUrl}')`
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
  lazyLoad: PropTypes.bool,
  backgroundSize: PropTypes.string
};

CoverImage.defaultProps = {
  backgroundSize: "cover"
};

export default CoverImage;
