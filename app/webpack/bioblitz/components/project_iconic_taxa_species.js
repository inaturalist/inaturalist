import _ from "lodash";
import React, { Component, PropTypes } from "react";
import NodeAPI from "../models/node_api";

class ProjectIconicTaxaSpecies extends Component {

  componentDidMount( ) {
    NodeAPI.fetch( `observations/iconic_taxa_species_counts?per_page=0&project_id=${this.props.projectID}` ).
      then( json => {
        this.props.setState( { iconicTaxaSpeciesCounts: json } );
      } ).
      catch( e => console.log( e ) );
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
            return (
              <div key={ r.taxon.id } style={ { width: `${width}%` } }>
                <span className="taxon">{ name }</span>
                <i className={ `icon icon-iconic-${r.taxon.name.toLowerCase( )}` } />
                <div className="bar" style={ { height: `${height}%` } } />
                <span className="value">{ Number( r.count ).toLocaleString( ) }</span>
              </div>
            );
          } ) }
        </div>
      );
    }
    return (
      <div className="slide vertical-barchart" id="iconic-taxa-species-slide">
        { graph }
        <h2>Species by category</h2>
      </div>
    );
  }
}

ProjectIconicTaxaSpecies.propTypes = {
  projectID: PropTypes.number,
  placeID: PropTypes.number,
  iconicTaxaSpeciesCounts: PropTypes.object,
  setState: PropTypes.func
};

export default ProjectIconicTaxaSpecies;
