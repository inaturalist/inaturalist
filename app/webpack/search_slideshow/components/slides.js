import React, { Component, PropTypes } from "react";
import ResultsMap from "./results_map";
import ResultsPeople from "./results_people";
import ResultsSpecies from "./results_species";
import ResultsPhotos from "./results_photos";

class Slides extends Component {

  constructor( props, context ) {
    super( props, context );
    this.showCurrentSlide = this.showCurrentSlide.bind( this );
    this.slideshowOrders = this.slideshowOrders.bind( this );
    this.setNextSlide = this.setNextSlide.bind( this );
  }

  componentDidMount( ) {
    this.refs.map.reloadData( );
    this.showCurrentSlide( );
  }

  setNextSlide( ) {
    const nextIndex = this.props.slideshowIndex + 1;
    if ( this.slideshowOrders( )[nextIndex] ) {
      // showing the next slide in the slideshow
      this.props.setState( { slideshowIndex: nextIndex } );
      this.showCurrentSlide( );
    } else {
      this.props.setState( { slideshowIndex: -1 } );
      this.setNextSlide( );
    }
  }

  showCurrentSlide( ) {
    const current = this.slideshowOrders( )[this.props.slideshowIndex];
    // fade in the next slide in the slideshow
    $( current.slide ).fadeIn( 2000 );
    if ( current.slide === ".map-slide" ) {
      this.refs.map.reloadMap( );
    }
    setTimeout( ( ) => {
      // after slide.duration ms, fade out this slide and set up the next one
      $( current.slide ).fadeOut( 2000 );
      this.setNextSlide( );
    }, current.duration );
  }

  slideshowOrders( ) {
    return [
      { slide: ".map-slide", duration: 8000 },
      { slide: ".people-slide", duration: 8000 },
      { slide: ".species-slide", duration: 8000 },
      { slide: ".photos-slide", duration: 8000 }
    ];
  }

  render( ) {
    return (
      <div id="slideshow">
        <ResultsMap { ...this.props } ref="map" />
        <ResultsPeople { ...this.props } />
        <ResultsSpecies { ...this.props } />
        <ResultsPhotos { ...this.props } />
      </div>
    );
  }
}

Slides.propTypes = {
  setState: PropTypes.func,
  slideshowIndex: PropTypes.number
};

export default Slides;
