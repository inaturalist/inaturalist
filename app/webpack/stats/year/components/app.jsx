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
                I18n.t( "users_year_on_site", { user: user.login, site: site.name } )
              ) : (
                I18n.t( "year_on_site", { site: site.name } )
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
