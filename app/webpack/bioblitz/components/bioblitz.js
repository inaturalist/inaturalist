import React, { Component, PropTypes } from "react";
import ProjectMap from "./project_map";
import ProjectIconicTaxa from "./project_iconic_taxa";
import ProjectIconicTaxaSpecies from "./project_iconic_taxa_species";
import ProjectPeople from "./project_people";
import ProjectSpecies from "./project_species";
import ProjectPhotos from "./project_photos";

class Bioblitz extends Component {

  constructor( props, context ) {
    super( props, context );
    this.transitionOne = this.transitionOne.bind( this );
    this.transitionTwo = this.transitionTwo.bind( this );
    this.transitionThree = this.transitionThree.bind( this );
    this.transitionFour = this.transitionFour.bind( this );
    this.transitionFive = this.transitionFive.bind( this );
    this.transitionSix = this.transitionSix.bind( this );
  }

  componentDidMount( ) {
    $( ".slide:gt(0)" ).hide( );
    setTimeout( this.transitionOne, 5000 );
  }

  transitionOne( ) {
    $( "#map-slide" ).fadeOut( 2000 );
    $( "#iconic-taxa-slide" ).fadeIn( 2000 );
    setTimeout( this.transitionTwo, 5000 );
  }

  transitionTwo( ) {
    $( "#iconic-taxa-slide" ).fadeOut( 2000 );
    $( "#iconic-taxa-species-slide" ).fadeIn( 2000 );
    setTimeout( this.transitionThree, 5000 );
  }

  transitionThree( ) {
    $( "#iconic-taxa-species-slide" ).fadeOut( 2000 );
    $( "#photos-slide" ).fadeIn( 2000 );
    setTimeout( this.transitionFour, 5000 );
  }

  transitionFour( ) {
    $( "#photos-slide" ).fadeOut( 2000 );
    $( "#people-slide" ).fadeIn( 2000 );
    setTimeout( this.transitionFive, 5000 );
  }

  transitionFive( ) {
    $( "#people-slide" ).fadeOut( 2000 );
    $( "#species-slide" ).fadeIn( 2000 );
    setTimeout( this.transitionSix, 5000 );
  }

  transitionSix( ) {
    $( "#species-slide" ).fadeOut( 2000 );
    $( "#map-slide" ).fadeIn( 2000 );
    setTimeout( this.transitionOne, 5000 );
  }

  render( ) {
    return (
      <div>
        <nav className="navbar">
          <div className="container-fluid">
            <div className="nav navbar-nav">
              <a href="/" title="iNaturalist" alt="iNaturalist">
                <img src="/logo-inat.svg" />
              </a>
            </div>
            <div className="nav navbar-nav navbar-title">
              { this.props.projectTitle }
            </div>
            <div className="nav navbar-nav navbar-right">
              <a href="/" title="NPS" alt="NPS">
                <img src="/logo-nps.svg" />
              </a>
            </div>
          </div>
        </nav>
        <div className="container-fluid content">
          <ProjectMap { ...this.props } />
          <ProjectIconicTaxa { ...this.props } />
          <ProjectIconicTaxaSpecies { ...this.props } />
          <ProjectPhotos { ...this.props } />
          <ProjectPeople { ...this.props } />
          <ProjectSpecies { ...this.props } />
        </div>
      </div>
    );
  }
}

Bioblitz.propTypes = {
  projectTitle: PropTypes.string
};

export default Bioblitz;
