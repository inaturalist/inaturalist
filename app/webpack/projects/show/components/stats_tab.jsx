import React, { Component } from "react";
import PropTypes from "prop-types";
import { Grid, Row, Col } from "react-bootstrap";
import IconicTaxaPieChart from "./iconic_taxa_pie_chart";
import QualityGradePieChart from "./quality_grade_pie_chart";
import IdCategoryPieChart from "./id_category_pie_chart";
import ObservationsFlexGridView from "./observations_flex_grid_view";

class StatsTab extends Component {

  componentDidMount( ) {
    this.props.fetchQualityGradeCounts( );
    this.props.fetchIdentificationCategories( );
    this.props.fetchPopularObservations( );
  }

  render( ) {
    const { config, project } = this.props;
    return (
      <div className="TopSpecies">
        <Grid>
          <Row>
            <Col xs={ 12 }>
              <h2>
                { I18n.t( "stats" ) }
              </h2>
            </Col>
          </Row>
          <Row>
            <Col xs={ 4 }>
              <QualityGradePieChart { ...this.props } />
            </Col>
            <Col xs={ 4 }>
              <IconicTaxaPieChart { ...this.props } />
            </Col>
            <Col xs={ 4 }>
              <IdCategoryPieChart { ...this.props } />
            </Col>
          </Row>
          { !( project.popular_observations_loaded && project.popular_observations.total_results === 0 ) && (
            <Row>
              <Col xs={ 12 } className="popular">
                { project.popular_observations_loaded ? (
                  <div>
                    <h2>{ I18n.t( "most_comments_and_faves" ) }</h2>
                    <ObservationsFlexGridView
                      config={ config }
                      scrollIndex={ 50 }
                      observations={ project.popular_observations.results }
                      hasMore={ false }
                      loadMore={ ( ) => { } }
                    />
                  </div> ) :
                  ( <div className="loading_spinner huge" /> )
                }
              </Col>
            </Row>
          ) }
        </Grid>
      </div>
    );
  }
}

StatsTab.propTypes = {
  config: PropTypes.object,
  project: PropTypes.object,
  fetchIdentificationCategories: PropTypes.func,
  fetchPopularObservations: PropTypes.func,
  fetchQualityGradeCounts: PropTypes.func,
  setConfig: PropTypes.func,
  species: PropTypes.array
};

export default StatsTab;
