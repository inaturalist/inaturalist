import _ from "lodash";
import React from "react";
import PropTypes from "prop-types";

class App extends React.Component {
  constructor( ) {
    super( );
    this.map = null;
  }

  render( ) {
    const { taxa, setOrderBy, config } = this.props;
    const order = `${config.orderBy}::${config.order}`;
    return (
      <div id="TaxonGeoExplainIndex" className="container">
        <h2>TaxonGeoExplainIndex</h2>
        <table className="table">
          <thead>
            <tr>
              <th onClick={( ) => setOrderBy( "id", "asc" )}>
                ID
                { order === "id::asc" && ( <i className="fa fa-caret-up" /> ) }
                { order === "id::desc" && ( <i className="fa fa-caret-down" /> ) }
              </th>
              <th onClick={( ) => setOrderBy( "name", "asc" )}>
                Name
                { order === "name::asc" && ( <i className="fa fa-caret-up" /> ) }
                { order === "name::desc" && ( <i className="fa fa-caret-down" /> ) }
              </th>
              <th onClick={( ) => setOrderBy( "prauc", "desc" )}>
                prauc
                { order === "prauc::asc" && ( <i className="fa fa-caret-up" /> ) }
                { order === "prauc::desc" && ( <i className="fa fa-caret-down" /> ) }
              </th>
              <th onClick={( ) => setOrderBy( "precision", "desc" )}>
                Precision
                { order === "precision::asc" && ( <i className="fa fa-caret-up" /> ) }
                { order === "precision::desc" && ( <i className="fa fa-caret-down" /> ) }
              </th>
              <th onClick={( ) => setOrderBy( "recall", "desc" )}>
                Recall
                { order === "recall::asc" && ( <i className="fa fa-caret-up" /> ) }
                { order === "recall::desc" && ( <i className="fa fa-caret-down" /> ) }
              </th>
              <th onClick={( ) => setOrderBy( "f1", "desc" )}>
                F1
                { order === "f1::asc" && ( <i className="fa fa-caret-up" /> ) }
                { order === "f1::desc" && ( <i className="fa fa-caret-down" /> ) }
              </th>
              <th onClick={( ) => setOrderBy( "elev_threshold", "desc" )}>
                Elev Threshold
                { order === "elev_threshold::asc" && ( <i className="fa fa-caret-up" /> ) }
                { order === "elev_threshold::desc" && ( <i className="fa fa-caret-down" /> ) }
              </th>
              <th onClick={( ) => setOrderBy( "no_elev_threshold", "desc" )}>
                NoElev Threshold
                { order === "no_elev_threshold::asc" && ( <i className="fa fa-caret-up" /> ) }
                { order === "no_elev_threshold::desc" && ( <i className="fa fa-caret-down" /> ) }
              </th>
            </tr>
          </thead>
          <tbody>
            { _.map( taxa, taxon => (
              <tr key={`taxon-row-${taxon.taxon_id}`}>
                <td>{ taxon.taxon_id }</td>
                <td><a href={`/geo_model/${taxon.taxon_id}/explain`}>{ taxon.name }</a></td>
                <td>{ taxon.prauc }</td>
                <td>{ taxon.precision }</td>
                <td>{ taxon.recall }</td>
                <td>{ taxon.f1 }</td>
                <td>{ taxon.elev_threshold }</td>
                <td>{ taxon.no_elev_threshold }</td>
              </tr>
            ) ) }
          </tbody>
        </table>
      </div>
    );
  }
}

App.propTypes = {
  taxa: PropTypes.array,
  config: PropTypes.object,
  setOrderBy: PropTypes.func
};

App.defaultProps = {
  taxa: [],
  config: {}
};

export default App;