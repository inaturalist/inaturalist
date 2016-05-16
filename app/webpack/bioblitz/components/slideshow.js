import _ from "lodash";
import React, { Component, PropTypes } from "react";
import ProjectMap from "./project_map";
import ProjectIconicTaxa from "./project_iconic_taxa";
import ProjectIconicTaxaSpecies from "./project_iconic_taxa_species";
import ProjectPeople from "./project_people";
import ProjectSpecies from "./project_species";
import ProjectPhotos from "./project_photos";
import TopProjects from "./top_projects";

class Slideshow extends Component {

  constructor( props, context ) {
    super( props, context );
    this.nextSlide = this.nextSlide.bind( this );
  }

  componentDidMount( ) {
    this.nextSlide( );
  }

  nextSlide( ) {
    const isUmbrella = this.props.umbrellaSubProjects[this.props.project.id];
    const slideOrders = isUmbrella ?
      this.props.overallProjectSlideshowOrder : this.props.subProjectSlideshowOrder;
    const next = slideOrders[this.props.slideshowIndex];
    $( next.slide ).fadeIn( 2000 );
    if ( next.slide === ".subproject-map-slide" ) {
      this.refs.map.reloadData( );
    }
    if ( next.slide === ".umbrella-map-slide" ) {
      this.refs.umbrellaMap.reloadData( );
    }
    const nextColor = `color${( this.props.colorIndex )}`;
    if ( !$( "#app" ).hasClass( nextColor ) ) {
      $( "#app" ).removeClass( );
      $( "#app" ).addClass( `color${( this.props.colorIndex )}` );
    }
    if ( next.slide === ".top-projects-slide" ) {
      $( "#app" ).addClass( "top-projects" );
    }
    $( "#main-container" ).removeClass( );
    $( "#main-container" ).addClass( `phase${( this.props.slideshowIndex )}` );
    setTimeout( ( ) => {
      $( next.slide ).fadeOut( 2000 );
      const nextIndex = this.props.slideshowIndex + 1;
      if ( slideOrders[nextIndex] ) {
        this.props.setState( { slideshowIndex: nextIndex } );
        this.nextSlide( );
      } else {
        $( "#app" ).addClass( "transition" );
        setTimeout( ( ) => {
          if ( isUmbrella ) {
            this.props.setState( {
              slideshowIndex: 0,
              slideshowSubProjectIndex: 0,
              colorIndex: ( this.props.colorIndex + 1 ) % this.props.countColors,
              umbrellaProject: this.props.project,
              project: _.values( this.props.umbrellaSubProjects[this.props.project.id] )[0],
              overallStats: { },
              iconicTaxaCounts: { },
              iconicTaxaSpeciesCounts: { },
              peopleStats: { },
              speciesStats: { }
            } );
            this.nextSlide( );
          } else {
            const nextSubprojectIndex = this.props.slideshowSubProjectIndex + 1;
            if ( nextSubprojectIndex > this.props.umbrellaProject.slideshow_count - 1 ) {
              const nextUmbrellaIndex = this.props.slideshowUmbrellaIndex + 1;
              if ( nextUmbrellaIndex > this.props.umbrellaProjects.length - 1 ) {
                window.location.reload(false);
              } else {
                this.props.setState( {
                  slideshowUmbrellaIndex: nextUmbrellaIndex,
                  slideshowIndex: 0,
                  slideshowSubProjectIndex: null,
                  colorIndex: ( this.props.colorIndex + 1 ) % this.props.countColors,
                  umbrellaProject: null,
                  project: this.props.umbrellaProjects[nextUmbrellaIndex],
                  overallStats: { },
                  iconicTaxaCounts: { },
                  iconicTaxaSpeciesCounts: { },
                  peopleStats: { },
                  speciesStats: { }
                } );
                this.nextSlide( );
              }
            } else {
              this.props.setState( {
                slideshowIndex: 0,
                slideshowSubProjectIndex: nextSubprojectIndex,
                project: _.values( this.props.umbrellaSubProjects[
                  this.props.umbrellaProject.id] )[nextSubprojectIndex],
                colorIndex: ( this.props.colorIndex + 1 ) % this.props.countColors,
                overallStats: { },
                iconicTaxaCounts: { },
                iconicTaxaSpeciesCounts: { },
                peopleStats: { },
                speciesStats: { }
              } );
              this.nextSlide( );
            }
          }
        }, 1500 );
      }
    }, next.duration );
  }

  render( ) {
    return (
      <div id="slideshow">
        <ProjectMap { ...this.props } ref="map" />
        <ProjectIconicTaxa { ...this.props } />
        <ProjectIconicTaxaSpecies { ...this.props } />
        <ProjectPeople { ...this.props } />
        <ProjectSpecies { ...this.props } />
        <ProjectPhotos { ...this.props } />
        <ProjectMap umbrella { ...this.props } ref="umbrellaMap" />
        <TopProjects { ...this.props } />
      </div>
    );
  }
}

Slideshow.propTypes = {
  project: PropTypes.object,
  umbrellaProject: PropTypes.object,
  setState: PropTypes.func,
  colorIndex: PropTypes.number,
  countColors: PropTypes.number,
  allSubProjects: PropTypes.array,
  slideshowIndex: PropTypes.number,
  umbrellaProjects: PropTypes.array,
  umbrellaSubProjects: PropTypes.object,
  slideshowUmbrellaIndex: PropTypes.number,
  slideshowSubProjectIndex: PropTypes.number,
  subProjectSlideshowOrder: PropTypes.array,
  overallProjectSlideshowOrder: PropTypes.array
};

export default Slideshow;
