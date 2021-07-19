import React from "react";
import PropTypes from "prop-types";
import ReactDOM from "react-dom";
import { Button } from "react-bootstrap";
import _ from "lodash";

class Carousel extends React.Component {
  constructor( ) {
    super( );
    this.state = {
      currentIndex: 0,
      sliding: false
    };
  }

  componentDidMount( ) {
    const domNode = ReactDOM.findDOMNode( this );
    const that = this;
    $( ".carousel", domNode ).on( "slid.bs.carousel", ( ) => {
      that.setState( { sliding: false } );
    } );
  }

  showNext( ) {
    const domNode = ReactDOM.findDOMNode( this );
    $( ".carousel", domNode ).carousel( "next" );
    const { currentIndex } = this.state;
    this.setState( {
      currentIndex: currentIndex + 1,
      sliding: true
    } );
  }

  showPrev( ) {
    const domNode = ReactDOM.findDOMNode( this );
    $( ".carousel", domNode ).carousel( "prev" );
    const { currentIndex } = this.state;
    this.setState( {
      currentIndex: currentIndex - 1,
      sliding: true
    } );
  }

  render( ) {
    let link;
    if ( this.props.url ) {
      link = (
        <a href={this.props.url} className="readmore">
          { I18n.t( "view_all" ) }
        </a>
      );
    }
    let description;
    if ( this.props.description ) {
      description = (
        <p>{ this.props.description }</p>
      );
    }
    let noContent;
    let nav;
    if ( this.props.items.length === 0 ) {
      noContent = (
        <p className="text-muted text-center">
          { this.props.noContent }
        </p>
      );
    } else if ( this.props.items.length > 1 ) {
      nav = (
        <div className="carousel-controls pull-right nav-buttons">
          <Button
            className="nav-btn prev-btn"
            disabled={this.state.currentIndex === 0 || this.state.sliding}
            onClick={( ) => this.showPrev( )}
            title={I18n.t( "previous_taxon_short" )}
          />
          <Button
            className="nav-btn next-btn"
            disabled={this.state.currentIndex >= this.props.items.length - 1 || this.state.sliding}
            onClick={( ) => this.showNext( )}
            title={I18n.t( "next_taxon_short" )}
          />
        </div>
      );
    }
    return (
      <div className={`Carousel ${this.props.className}`}>
        { nav }
        <h2>
          { this.props.title }
          { link }
        </h2>
        { description }
        { noContent }
        <div
          className="carousel slide"
          data-ride="carousel"
          data-interval="false"
          data-wrap="false"
          data-keyboard="false"
        >
          <div className="carousel-inner">
            { _.map( this.props.items, ( item, index ) => (
              <div
                key={`${_.kebabCase( this.props.title )}-carousel-item-${index}`}
                className={`carousel-item-${index} item ${index === 0 ? "active" : ""}`}
              >
                { item }
              </div>
            ) ) }
          </div>
        </div>
      </div>
    );
  }
}

Carousel.propTypes = {
  title: PropTypes.string.isRequired,
  url: PropTypes.string,
  description: PropTypes.oneOfType( [
    PropTypes.string,
    PropTypes.object
  ] ),
  noContent: PropTypes.string,
  items: PropTypes.array.isRequired,
  className: PropTypes.string
};

export default Carousel;
