import _ from "lodash";
import React, { PropTypes } from "react";
import { Grid, Row, Col } from "react-bootstrap";
import ObservationsFlexGridView from "./observations_flex_grid_view";
import ObservationsListView from "./observations_list_view";
import ObservationsMapView from "./observations_map_view";

const ObservationsTab = ( {
  config,
  project,
  observations,
  infiniteScrollObservations,
  setSelectedTab
} ) => {
  const scrollIndex = config.observationsScrollIndex || 30;
  let view;
  const activeSubview = config.observationsSearchSubview || "grid";
  if ( _.isEmpty( observations ) ) {
    view = ( <div className="loading_spinner huge" /> );
  } else if ( _.isEmpty( observations ) ) {
    view = ( <span /> );
  } else if ( activeSubview === "map" ) {
    view = (
      <ObservationsMapView
        project={ project }
      />
    );
  } else if ( activeSubview === "table" ) {
    view = (
      <ObservationsListView
        config={ config }
        observations={ observations }
        loadMore={ ( ) => {
          infiniteScrollObservations( scrollIndex + 30 );
        } }
        hasMore={ observations.length >= scrollIndex && scrollIndex < 200 }
      />
    );
  } else {
    view = (
      <ObservationsFlexGridView
        config={ config }
        observations={ observations }
        loadMore={ ( ) => {
          infiniteScrollObservations( scrollIndex + 30 );
        } }
        hasMore={ observations.length >= scrollIndex && scrollIndex < 200 }
      />
    );
  }
  return (
    <div className="ObservationsTab">
      <Grid>
        <Row className="button-row">
          <Col xs={ 12 }>
            <div className="btn-group">
              <button
                className={ `btn btn-default ${activeSubview === "map" && "active"}` }
                onClick={ ( ) => setSelectedTab( "observations", { subtab: "map" } ) }
              >
                <i className="fa fa-map-marker" />
                { I18n.t( "map" ) }
              </button>
              <button
                className={ `btn btn-default ${activeSubview === "grid" && "active"}` }
                onClick={ ( ) => setSelectedTab( "observations", { subtab: "grid" } ) }
              >
                <i className="fa fa-th" />
                { I18n.t( "grid" ) }
              </button>
              <button
                className={ `btn btn-default ${activeSubview === "table" && "active"}` }
                onClick={ ( ) => setSelectedTab( "observations", { subtab: "table" } ) }
              >
                <i className="fa fa-bars" />
                { I18n.t( "list" ) }
              </button>
            </div>
            <a href={ `/observations/identify?project_id=${project.slug}` }>
              <button className="btn btn-default standalone">
                <i className="icon-identification" />
                { I18n.t( "identify" ) }
              </button>
            </a>
            <a href={ `/observations?project_id=${project.slug}&verifiable=any&place=any` }>
              <button className="btn btn-default standalone">
                <i className="fa fa-search" />
                { I18n.t( "search" ) }
              </button>
            </a>
            <a href={ `/observations/export?projects=${project.slug}` }>
              <button className="btn btn-default standalone export">
                <i className="fa fa-external-link" />
                { I18n.t( "export_observations" ) }
              </button>
            </a>
          </Col>
        </Row>
      </Grid>
      <div className="subtab-contents">
        { view }
      </div>
    </div>
  );
};

ObservationsTab.propTypes = {
  config: PropTypes.object,
  project: PropTypes.object,
  setConfig: PropTypes.func,
  infiniteScrollObservations: PropTypes.func,
  setSelectedTab: PropTypes.func,
  observations: PropTypes.array
};

export default ObservationsTab;
