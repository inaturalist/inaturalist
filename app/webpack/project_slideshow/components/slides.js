import _ from "lodash";
import React, { Component, PropTypes } from "react";
import ProjectMap from "./project_map";
import ProjectIconicTaxa from "./project_iconic_taxa";
import ProjectIconicTaxaSpecies from "./project_iconic_taxa_species";
import ProjectPeople from "./project_people";
import ProjectSpecies from "./project_species";
import ProjectPhotos from "./project_photos";
import TopProjects from "./top_projects";

const baseStats = {
  overallStats: { },
  iconicTaxaCounts: { },
  iconicTaxaSpeciesCounts: { },
  peopleStats: { },
  speciesStats: { }
};

class Slides extends Component {

  constructor( props, context ) {
    super( props, context );
    this.showCurrentSlide = this.showCurrentSlide.bind( this );
    this.currentProjectIsUmbrella = this.currentProjectIsUmbrella.bind( this );
    this.currentProjectSlideshowOrders = this.currentProjectSlideshowOrders.bind( this );
    this.setNextSlide = this.setNextSlide.bind( this );
    this.nextColorIndex = this.nextColorIndex.bind( this );
    this.nextSubprojectInUmbrella = this.nextSubprojectInUmbrella.bind( this );
    this.nextUmbrellaProject = this.nextUmbrellaProject.bind( this );
  }

  componentDidMount( ) {
    this.showCurrentSlide( );
  }

  setNextSlide( ) {
    const nextIndex = this.props.slideshowIndex + 1;
    if ( this.currentProjectSlideshowOrders( )[nextIndex] ) {
      // showing the next slide in this project's slideshow
      this.props.setState( { slideshowIndex: nextIndex } );
      this.showCurrentSlide( );
    } else {
      // transitioning from one project to another
      $( "#app" ).addClass( "transition" );
      setTimeout( ( ) => {
        const nextSubproject = this.nextSubprojectInUmbrella( );
        if ( nextSubproject ) {
          this.props.setState( Object.assign( {
            slideshowIndex: 0,
            slideshowSubProjectIndex: nextSubproject.subprojectIndex,
            colorIndex: this.nextColorIndex( ),
            slidesShownForUmbrella: ( this.props.slidesShownForUmbrella || 0 ) + 1,
            umbrellaProject: this.props.umbrellaProject || this.props.project,
            project: nextSubproject.subproject
          }, baseStats ) );
          this.showCurrentSlide( );
        } else {
          const nextUmbrella = this.nextUmbrellaProject( );
          if ( nextUmbrella ) {
            this.props.setState( Object.assign( {
              slideshowUmbrellaIndex: nextUmbrella.umbrellaProjectIndex,
              slideshowIndex: 0,
              slideshowSubProjectIndex: null,
              colorIndex: this.nextColorIndex( ),
              umbrellaProject: null,
              project: nextUmbrella.umbrellaProject
            }, baseStats ) );
            this.showCurrentSlide( );
          } else {
            // there is no next slide, we've shown them all
            // reload the page to fetch new date and start over
            window.location.reload( false );
          }
        }
      }, 1500 );
    }
  }

  showCurrentSlide( ) {
    const current = this.currentProjectSlideshowOrders( )[this.props.slideshowIndex];
    // fade in the next slide in this project's slideshow
    $( current.slide ).fadeIn( 2000 );
    // if the slide is a map slide, need to refresh it now that it's longer hidden
    if ( current.slide === ".subproject-map-slide" ) {
      this.refs.map.reloadData( );
    }
    if ( current.slide === ".umbrella-map-slide" ) {
      this.refs.umbrellaMap.reloadData( );
    }
    // apply this slides color, which will transition in as the slide fades in
    const nextColor = `color${( this.props.colorIndex )}`;
    if ( !$( "#app" ).hasClass( nextColor ) ) {
      $( "#app" ).removeClass( );
      $( "#app" ).addClass( `color${( this.props.colorIndex )}` );
    }
    // top project slides use their own custom colors
    if ( current.slide === ".top-projects-slide" ) {
      $( "#app" ).addClass( "top-projects" );
    }
    // apply the phase class, which determines how dark the slide background is
    $( "#main-container" ).removeClass( );
    $( "#main-container" ).addClass( `phase${( this.props.slideshowIndex )}` );
    setTimeout( ( ) => {
      // after slide.duration ms, fade out this slide and set up the next one
      $( current.slide ).fadeOut( 2000 );
      this.setNextSlide( );
    }, current.duration );
  }

  currentProjectIsUmbrella( ) {
    if ( this.props.singleProject ) { return false; }
    return this.props.umbrellaSubProjects[this.props.project.id];
  }

  currentProjectSlideshowOrders( ) {
    return this.currentProjectIsUmbrella( ) ?
      this.props.overallProjectSlideshowOrder : this.props.subProjectSlideshowOrder;
  }

  nextColorIndex( ) {
    return ( this.props.colorIndex + 1 ) % this.props.countColors;
  }

  nextSubprojectInUmbrella( ) {
    if ( this.props.singleProject ) { return false; }
    const isUmbrella = this.props.umbrellaSubProjects[this.props.project.id];
    let umbrellaProject = this.props.umbrellaProject;
    if ( !this.props.umbrellaProject && isUmbrella ) {
      umbrellaProject = this.props.project;
    }
    if ( !umbrellaProject ) { return false; }
    // we've shown enough slides for this umbrella already
    if ( this.props.slidesShownForUmbrella >= umbrellaProject.slideshow_count ) {
      return false;
    }
    let nextSubproject;
    let nextSubprojectIndex = ( this.props.slideshowSubProjectIndex === null ) ?
      -1 : this.props.slideshowSubProjectIndex;
    while ( !nextSubproject ) {
      nextSubprojectIndex += 1;
      const projectAtIndex = _.values( this.props.umbrellaSubProjects[
        umbrellaProject.id] )[nextSubprojectIndex];
      // there are no more projects in this umbrella to show - stop
      if ( !projectAtIndex ) { break; }
      // there are no observations in this subproject - skip it
      if ( !projectAtIndex.observation_count ) { continue; }
      nextSubproject = projectAtIndex;
      return { subproject: nextSubproject, subprojectIndex: nextSubprojectIndex };
    }
    return false;
  }

  nextUmbrellaProject( ) {
    if ( this.props.singleProject ) { return false; }
    const nextUmbrellaIndex = this.props.slideshowUmbrellaIndex + 1;
    if ( nextUmbrellaIndex < this.props.umbrellaProjects.length ) {
      return {
        umbrellaProject: this.props.umbrellaProjects[nextUmbrellaIndex],
        umbrellaProjectIndex: nextUmbrellaIndex
      };
    }
    return false;
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

Slides.propTypes = {
  project: PropTypes.object,
  singleProject: PropTypes.object,
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
  overallProjectSlideshowOrder: PropTypes.array,
  slidesShownForUmbrella: PropTypes.number
};

export default Slides;
