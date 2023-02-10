import React from "react";
import PropTypes from "prop-types";
import { Grid, Row, Col } from "react-bootstrap";
import ObservationsFlexGridView from "./observations_flex_grid_view";
import ObservationsListView from "./observations_list_view";
import ObservationsMapView from "./observations_map_view";

const ObservationsTab = ( {
  config,
  project,
  infiniteScrollObservations,
  setSelectedTab,
  setObservationFilters,
  updateCurrentUser
} ) => {
  const scrollIndex = config.observationsScrollIndex || 30;
  let view;
  const activeSubview = config.observationsSearchSubview || "grid";
  let observations;
  let loading;
  if ( activeSubview === "table" ) {
    loading = !project.filtered_observations_loaded;
    observations = loading ? null : project.filtered_observations.results;
  } else {
    loading = !project.recent_observations_loaded;
    observations = loading ? null : project.recent_observations.results;
  }
  if ( loading ) {
    view = <div key="observations-tab-loading-spinner" className="loading_spinner huge" />;
  } else if ( activeSubview === "map" ) {
    view = (
      <ObservationsMapView
        project={project}
        config={config}
        updateCurrentUser={updateCurrentUser}
      />
    );
  } else if ( activeSubview === "table" ) {
    view = (
      <ObservationsListView
        config={config}
        loading={loading}
        setObservationFilters={setObservationFilters}
        observations={loading ? null : project.filtered_observations.results}
        loadMore={( ) => {
          infiniteScrollObservations( scrollIndex, scrollIndex + 30 );
        }}
        hasMore={observations && observations.length >= scrollIndex && scrollIndex < 200}
        showViewMoreLink={observations && observations.length >= scrollIndex && scrollIndex >= 200}
        viewMoreUrl={`/observations?project_id=${project.slug}&verifiable=any&place_id=any&subview=table`}
      />
    );
  } else {
    view = (
      <ObservationsFlexGridView
        config={config}
        observations={observations}
        scrollIndex={config.observationsScrollIndex}
        loadMore={( ) => {
          infiniteScrollObservations( scrollIndex, scrollIndex + 30 );
        }}
        hasMore={observations && observations.length >= scrollIndex && scrollIndex < 200}
        showViewMoreLink={observations && observations.length >= scrollIndex && scrollIndex >= 200}
        viewMoreUrl={`/observations?project_id=${project.slug}&verifiable=any&place_id=any&subview=grid`}
      />
    );
  }
  return (
    <div className="ObservationsTab">
      <Grid>
        <Row className="button-row">
          <Col xs={12}>
            <div className="btn-group">
              <button
                type="button"
                className={`btn btn-default ${activeSubview === "map" && "active"}`}
                onClick={( ) => setSelectedTab( "observations", { subtab: "map" } )}
              >
                <i className="fa fa-map-marker" />
                { I18n.t( "map" ) }
              </button>
              <button
                type="button"
                className={`btn btn-default ${activeSubview === "grid" && "active"}`}
                onClick={( ) => setSelectedTab( "observations", { subtab: "grid" } )}
              >
                <i className="fa fa-th" />
                { I18n.t( "grid" ) }
              </button>
              <button
                type="button"
                className={`btn btn-default ${activeSubview === "table" && "active"}`}
                onClick={( ) => setSelectedTab( "observations", { subtab: "table" } )}
              >
                <i className="fa fa-bars" />
                { I18n.t( "list" ) }
              </button>
            </div>
            <a href={`/observations/identify?project_id=${project.slug}`}>
              <button type="button" className="btn btn-default standalone">
                <i className="icon-identification" />
                { I18n.t( "identify" ) }
              </button>
            </a>
            <a href={`/observations?project_id=${project.slug}&verifiable=any&place_id=any`}>
              <button type="button" className="btn btn-default standalone">
                <i className="fa fa-search" />
                { I18n.t( "search" ) }
              </button>
            </a>
            <a href={`/observations/export?projects=${project.slug}`}>
              <button type="button" className="btn btn-default standalone export">
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
  infiniteScrollObservations: PropTypes.func,
  setSelectedTab: PropTypes.func,
  setObservationFilters: PropTypes.func,
  updateCurrentUser: PropTypes.func
};

export default ObservationsTab;
