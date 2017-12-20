import React from "react";
import { Grid, Row, Col } from "react-bootstrap";
import GenerateStatsButton from "./generate_stats_button";
import Observations from "./observations";
import Identifications from "./identifications";

const App = ( {
  year,
  user,
  currentUser,
  site,
  data
} ) => {
  let body = "todo";
  if ( !year ) {
    body = (
      <p className="alert alert-warning">
        Not a valid year. Please choose a year between 1950 and { new Date().getYear() }.
      </p>
    );
  } else if ( !data ) {
    if ( user && currentUser && user.id === currentUser.id ) {
      body = (
        <GenerateStatsButton user={ user } />
      );
    } else {
      body = (
        <p className="alert alert-warning">
          Data for this year hasn't been generated yet.
        </p>
      );
    }
  } else {
    body = (
      <div>
        <Row>
          <Col xs={ 4 }>
            { data.observations.quality_grade_counts ? (
              <div className="summary">
                <div
                  className="main"
                  dangerouslySetInnerHTML={ { __html: I18n.t( "x_observations_html", {
                    count: I18n.toNumber(
                      (
                        data.observations.quality_grade_counts.research + data.observations.quality_grade_counts.needs_id
                      ),
                      { precision: 0 }
                    )
                  } ) } }
                >
                </div>
                <div className="research">
                  <span className="count">
                    { I18n.toNumber(
                      data.observations.quality_grade_counts.research,
                      { precision: 0 }
                    ) }
                  </span> { I18n.t( "research_grade" ) }
                </div>
                <div className="needs_id">
                  <span className="count">
                    { I18n.toNumber(
                      data.observations.quality_grade_counts.needs_id,
                      { precision: 0 }
                    ) }
                  </span> { I18n.t( "needs_id" ) }
                </div>
                <div className="casual">
                  <span className="count">
                    { I18n.toNumber(
                      data.observations.quality_grade_counts.casual,
                      { precision: 0 }
                    ) }
                  </span> { I18n.t( "casual" ) }
                </div>
              </div>
            ) : null }
          </Col>
          <Col xs={ 4 }>
            species summary
          </Col>
          <Col xs={ 4 }>
            ident summary
          </Col>
        </Row>
        <Observations data={ data.observations } />
        <Identifications data={ data.identifications } />
        { user && currentUser && user.id === currentUser.id ? (
          <GenerateStatsButton user={ user } text={ "Regenerate Stats" } />
        ) : null }
      </div>
    );
  }
  return (
    <div id="YearStats">
      <Grid>
        <Row>
          <Col xs={ 12 }>
            <h1>
              { user ? (
                I18n.t( "users_year_on_site", { user: user.login, site: site.name, year } )
              ) : (
                I18n.t( "year_on_site", { site: site.name, year } )
              ) }
            </h1>
          </Col>
        </Row>
        <Row>
          <Col xs={ 12 }>
            { body }
          </Col>
        </Row>
      </Grid>
    </div>
  );
};

App.propTypes = {
  year: React.PropTypes.number,
  user: React.PropTypes.object,
  currentUser: React.PropTypes.object,
  data: React.PropTypes.object,
  site: React.PropTypes.object
};

export default App;
