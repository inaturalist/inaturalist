import _ from "lodash";
import React, { Component, PropTypes } from "react";
import Util from "../models/util";

class ProjectIconicTaxaSpecies extends Component {

  constructor( props, context ) {
    super( props, context );
    this.reloadData = this.reloadData.bind( this );
  }

  componentDidMount( ) {
    this.reloadData( );
  }

  componentDidUpdate( prevProps ) {
    if ( prevProps.project.id !== this.props.project.id ) {
      this.reloadData( );
    }
  }

  reloadData( ) {
    /* eslint no-console: 0 */
    Util.nodeApiFetch(
      `observations/iconic_taxa_species_counts?per_page=0&project_id=${this.props.project.id}&ttl=600` ).
      then( json => {
        this.props.setState( { iconicTaxaSpeciesCounts: json } );
      } ).catch( e => console.log( e ) );
  }

  render( ) {
    let graph;
    if ( this.props.iconicTaxaSpeciesCounts.total_results ) {
      const categories = _.reject( this.props.iconicTaxaSpeciesCounts.results, r =>
        r.taxon.id === 1 ).slice( 0, 12 );
      const maxValue = this.props.iconicTaxaSpeciesCounts.results[0].count;
      const width = 100 / categories.length;
      graph = (
        <div className="chart">
          { _.map( categories, r => {
            const height = ( r.count / maxValue ) * 100;
            let name = r.taxon.preferred_common_name;
            if ( r.taxon.id === 47170 ) { name = "Fungi"; }
            if ( r.taxon.id === 47178 ) { name = "Fishes"; }
            if ( r.taxon.id === 48222 ) { name = "Chromista"; }
            return (
              <div key={ r.taxon.id } style={ { width: `${width}%` } }>
                <span className="taxon">{ name }</span>
                <i className={ `icon icon-iconic-${r.taxon.name.toLowerCase( )}` } />
                <div className="bar" style={ { height: `${height}%` } } />
                <span className="value">{ Util.numberWithCommas( r.count ) }</span>
              </div>
            );
          } ) }
        </div>
      );
    }
    return (
      <div className="slide vertical-barchart iconic-taxa-species-slide">
        { graph }
        <h2>Species by category</h2>
      </div>
    );
  }
}

ProjectIconicTaxaSpecies.propTypes = {
  project: PropTypes.object,
  iconicTaxaSpeciesCounts: PropTypes.object,
  setState: PropTypes.func
};

export default ProjectIconicTaxaSpecies;
