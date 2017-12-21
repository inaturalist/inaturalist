import React from "react";
import { Grid, Row, Col } from "react-bootstrap";
import inatjs from "inaturalistjs";
import _ from "lodash";
import UserImage from "../../../shared/components/user_image";
import GenerateStatsButton from "./generate_stats_button";
import Summary from "./summary";
import Observations from "./observations";
import Identifications from "./identifications";
import TaxaSunburst from "./taxa_sunburst";

const App = ( {
  year,
  user,
  currentUser,
  site,
  data
} ) => {
  let body = "todo";
  let inatUser = user ? new inatjs.User( user ) : null;
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
        <Summary data={data} />
        <Observations data={ data.observations } user={ user } year={ year } />
        <Identifications data={ data.identifications } />
        { user && ( <TaxaSunburst data={ data.taxa ? data.taxa.tree_taxa : null } /> ) }
        { user && currentUser && user.id === currentUser.id ? (
          <GenerateStatsButton user={ user } text={ "Regenerate Stats" } />
        ) : null }
      </div>
    );
  }
  let montageObservations = [];
  if ( data && data.observations && data.observations.popular ) {
    montageObservations = _.filter( data.observations.popular, o => ( o.photos && o.photos.length > 0 ) );
    while ( montageObservations.length < 100 ) {
      montageObservations = montageObservations.concat( montageObservations );
    }
  }
  return (
    <div id="YearStats">
      <div className="banner">
        <div className="montage">
          { _.map( montageObservations, ( o, i ) => (
            <a href={ `/observations/${o.id}` } key={ `montage-obs-${i}` }>
              <img src={ o.photos[0].url.replace( "square", "small" ) } />
            </a>
          ) ) }
        </div>
        { inatUser ? (
          <UserImage user={ inatUser } />
        ) : (
          <div className="site-icon">
            <img src={ site.icon_url } />
          </div>
        ) }
      </div>
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
