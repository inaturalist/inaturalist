import React from "react";
import PropTypes from "prop-types";
import ReactDOM from "react-dom";
import { Button } from "react-bootstrap";
import _ from "lodash";

class Carousel extends React.Component {
  constructor( ) {
    super( );
    this.state = {
      currentIndex: 0
    };
  }
  showNext( ) {
    const domNode = ReactDOM.findDOMNode( this );
    $( ".carousel", domNode ).carousel( "next" );
    this.setState( { currentIndex: this.state.currentIndex + 1 } );
  }
  showPrev( ) {
    const domNode = ReactDOM.findDOMNode( this );
    $( ".carousel", domNode ).carousel( "prev" );
    this.setState( { currentIndex: this.state.currentIndex - 1 } );
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
            disabled={this.state.currentIndex === 0}
            onClick={ ( ) => this.showPrev( ) }
            title={ I18n.t( "prev" ) }
          />
          <Button
            className="nav-btn next-btn"
            disabled={this.state.currentIndex >= this.props.items.length - 1}
            onClick={ ( ) => this.showNext( ) }
            title={ I18n.t( "next" ) }
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
