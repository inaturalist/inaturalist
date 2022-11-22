import React from "react";
import PropTypes from "prop-types";
import ReactDOM from "react-dom";
import {
  Row,
  Col,
  DropdownButton,
  MenuItem
} from "react-bootstrap";
import SpeciesComparisonContainer from "../containers/species_comparison_container";
import MapComparisonContainer from "../containers/map_comparison_container";
import HistoryComparisonContainer from "../containers/history_comparison_container";
// import SeasonalityComparisonContainer from "../containers/seasonality_comparison_container";

class Tabs extends React.Component {
  componentDidMount( ) {
    const domNode = ReactDOM.findDOMNode( this );
    $( "a[data-toggle=tab]", domNode ).on( "shown.bs.tab", e => {
      this.props.chooseTab( e.target.hash.match( /#(.+)-tab/ )[1] );
    } );
  }

  componentDidUpdate( prevProps ) {
    // very lame hack to make sure the map resizes correctly if it rendered when
    // not visible
    if ( this.props.chosenTab === "map" && prevProps.chosenTab !== "map" ) {
      const taxonMap = $( ".TaxonMap", ReactDOM.findDOMNode( this ) );
      if ( typeof ( google ) === "undefined" ) { return; }
      google.maps.event.trigger( taxonMap.data( "taxonMap" ), "resize" );
      taxonMap.taxonMap( taxonMap.data( "taxonMapOptions" ) );
    }
  }

  render( ) {
    const {
      chosenTab,
      showTaxonChildrenModal,
      colorScheme,
      chooseColorScheme
    } = this.props;
    return (
      <div className="Tabs stacked">
        <Row>
          <Col xs={12}>
            <div className="pull-right btn-toolbar">
              <DropdownButton
                title={`Colors: ${colorScheme}`}
                id="colors-dropdown"
                pullRight
                onSelect={chooseColorScheme}
              >
                <MenuItem eventKey="categorical">
                  Categorical
                </MenuItem>
                <MenuItem eventKey="sequential">
                  Sequential
                </MenuItem>
                <MenuItem eventKey="sequential_cool">
                  Sequential (cool)
                </MenuItem>
                <MenuItem eventKey="sequential_gray">
                  Sequential (gray)
                </MenuItem>
              </DropdownButton>
              <DropdownButton
                title="Tools"
                id="tools-dropdown"
                pullRight
                onSelect={key => {
                  if ( key === "taxon-children" ) {
                    showTaxonChildrenModal( );
                  }
                }}
              >
                <MenuItem eventKey="taxon-children">
                  Show taxon children
                </MenuItem>
              </DropdownButton>
            </div>
            <ul id="main-tabs" className="nav nav-tabs" role="tablist">
              <li role="presentation" className={chosenTab === "species" ? "active" : ""}>
                <a href="#species-tab" role="tab" data-toggle="tab">{ I18n.t( "species" ) }</a>
              </li>
              <li role="presentation" className={chosenTab === "map" ? "active" : ""}>
                <a href="#map-tab" role="tab" data-toggle="tab">{ I18n.t( "map" ) }</a>
              </li>
              <li role="presentation" className={chosenTab === "history" ? "active" : ""}>
                <a href="#history-tab" role="tab" data-toggle="tab">
                  { I18n.t( "history" ) }
                  { " / " }
                  { I18n.t( "seasonality" ) }
                </a>
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
                <MapComparisonContainer />
              </div>
              <div
                role="tabpanel"
                className={`tab-pane ${chosenTab === "history" ? "active" : ""}`}
                id="history-tab"
              >
                <HistoryComparisonContainer />
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
  chooseTab: PropTypes.func,
  chooseColorScheme: PropTypes.func,
  colorScheme: PropTypes.oneOf( [
    "categorical",
    "sequential",
    "sequential_cool",
    "sequential_gray",
    "custom"
  ] ),
  showTaxonChildrenModal: PropTypes.func
};

Tabs.defaultProps = {
  chosenTab: "species",
  colorScheme: "categorical"
};

export default Tabs;
