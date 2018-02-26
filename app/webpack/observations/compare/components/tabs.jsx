import React, { PropTypes } from "react";
import ReactDOM from "react-dom";
import { Row, Col } from "react-bootstrap";
import SpeciesComparisonContainer from "../containers/species_comparison_container";
import MapContainer from "../containers/map_container";

class Tabs extends React.Component {
  componentDidMount( ) {
    const domNode = ReactDOM.findDOMNode( this );
    $( "a[data-toggle=tab]", domNode ).on( "shown.bs.tab", e => {
      this.props.chooseTab( e.target.hash.match( /\#(.+)\-tab/ )[1] );
    } );
  }

  render( ) {
    const { chosenTab } = this.props;
    return (
      <div className="Tabs">
        <Row>
          <Col xs={12}>
            <ul id="main-tabs" className="nav nav-tabs" role="tablist">
              <li role="presentation" className={ chosenTab === "species" ? "active" : "" }>
                <a href="#species-tab" role="tab" data-toggle="tab">{ I18n.t( "species" ) }</a>
              </li>
              <li role="presentation" className={ chosenTab === "map" ? "active" : "" }>
                <a href="#map-tab" role="tab" data-toggle="tab">{ I18n.t( "map" ) }</a>
              </li>
            </ul>
          </Col>
        </Row>
        <Row>
          <Col xs={12}>
            <div id="main-tabs-content" className="tab-content">
              <div
                role="tabpanel"
                className={`tab-pane ${chosenTab === "species" ? "active" : ""}`}
                id="species-tab"
              >
                <SpeciesComparisonContainer />
              </div>
              <div
                role="tabpanel"
                className={`tab-pane ${chosenTab === "map" ? "active" : ""}`}
                id="map-tab"
              >
                <MapContainer />
              </div>
            </div>
          </Col>
        </Row>
      </div>
    );
  }
}

Tabs.propTypes = {
  chosenTab: PropTypes.string,
  chooseTab: PropTypes.func
};

Tabs.defaultProps = {
  chosenTab: "species"
};

export default Tabs;
