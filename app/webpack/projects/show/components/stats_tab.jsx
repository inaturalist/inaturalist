import React, { Component, PropTypes } from "react";
import { Grid, Row, Col } from "react-bootstrap";
import IconicTaxaPieChart from "./iconic_taxa_pie_chart";
import QualityGradePieChart from "./quality_grade_pie_chart";
import IdCategoryPieChart from "./id_category_pie_chart";

class StatsTab extends Component {

  componentDidMount( ) {
    this.props.fetchQualityGradeCounts( );
    this.props.fetchIdentificationCategories( );
  }

  render( ) {
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
        </Grid>
      </div>
    );
  }
}

StatsTab.propTypes = {
  config: PropTypes.object,
  fetchIdentificationCategories: PropTypes.func,
  fetchQualityGradeCounts: PropTypes.func,
  setConfig: PropTypes.func,
  species: PropTypes.array
};

export default StatsTab;
