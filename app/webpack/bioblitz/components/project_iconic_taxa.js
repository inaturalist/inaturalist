import _ from "lodash";
import React, { Component, PropTypes } from "react";
import NodeAPI from "../models/node_api";

class ProjectIconicTaxa extends Component {

  componentDidMount( ) {
    NodeAPI.fetch( `observations/iconic_taxa_counts?per_page=10&project_id=${this.props.projectID}` ).
      then( json => {
        this.props.setState( { iconicTaxaCounts: json } );
      } ).
      catch( e => console.log( e ) );
  }

  render( ) {
    let graph;
    if ( this.props.iconicTaxaCounts.total_results ) {
      const categories = _.reject( this.props.iconicTaxaCounts.results, r =>
        r.taxon.id === 1 ).slice( 0, 12 );
      const maxValue = this.props.iconicTaxaCounts.results[0].count;
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
      <div className="slide vertical-barchart" id="iconic-taxa-slide">
        { graph }
        <h2>Observations by category</h2>
      </div>
    );
  }
}

ProjectIconicTaxa.propTypes = {
  projectID: PropTypes.number,
  placeID: PropTypes.number,
  iconicTaxaCounts: PropTypes.object,
  setState: PropTypes.func
};

export default ProjectIconicTaxa;
