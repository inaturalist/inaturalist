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
    setTimeout( ( ) => {
      $( next.slide ).fadeOut( 2000 );
      const nextIndex = this.props.slideshowIndex + 1;
      if ( slideOrders[nextIndex] ) {
        this.props.setState( { slideshowIndex: nextIndex } );
        this.nextSlide( );
      } else {
        setTimeout( ( ) => {
          if ( isUmbrella ) {
            this.props.setState( {
              slideshowIndex: 0,
              slideshowSubProjectIndex: 0,
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
                overallStats: { },
                iconicTaxaCounts: { },
                iconicTaxaSpeciesCounts: { },
                peopleStats: { },
                speciesStats: { }
              } );
              this.nextSlide( );
            }
          }
        }, 2000 );
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
