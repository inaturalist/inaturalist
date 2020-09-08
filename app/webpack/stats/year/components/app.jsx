/* global DEFAULT_SITE_ID */
// I18n.t( "time.formats.long" )

import React from "react";
import PropTypes from "prop-types";
import { Grid, Row, Col } from "react-bootstrap";
import inatjs from "inaturalistjs";
import _ from "lodash";
import UserImage from "../../../shared/components/user_image";
import GenerateStatsButton from "./generate_stats_button";
import Summary from "./summary";
import Observations from "./observations";
import Identifications from "./identifications";
import Taxa from "./taxa";
import Publications from "./publications";
import Growth from "./growth";
import Compare from "./compare";
import Sites from "./sites";
import Donate from "./donate";
import Donor from "./donor";
import Translators from "./translators";

const App = ( {
  year,
  user,
  currentUser,
  site,
  sites,
  data,
  rootTaxonID,
  updatedAt
} ) => {
  let body = "todo";
  const inatUser = user ? new inatjs.User( user ) : null;
  const defaultSite = _.find( sites, s => s.id === DEFAULT_SITE_ID );
  if ( !year ) {
    body = (
      <p className="alert alert-warning">
        Not a valid year. Please choose a year between 1950 and
        { new Date().getYear() }
        .
      </p>
    );
  } else if ( !data || !currentUser ) {
    if ( user && currentUser && user.id === currentUser.id ) {
      body = (
        <GenerateStatsButton user={user} year={year} />
      );
    } else {
      body = (
        <p className="alert alert-warning">
          { I18n.t( "stats_for_this_year_have_not_been_generated" ) }
        </p>
      );
    }
  } else {
    body = (
      <div>
        <center>
          <a href="#sharing" className="btn btn-default btn-share btn-bordered">
            { I18n.t( "share" ) }
            { " " }
            <i className="fa fa-share-square-o" />
          </a>
        </center>
        <Summary data={data} user={user} year={year} site={site} currentUser={currentUser} />
        <Observations data={data.observations} user={user} year={year} site={site} />
        <Identifications
          data={data.identifications}
          user={user}
          currentUser={currentUser}
          year={year}
        />
        <Taxa
          data={data.taxa}
          rootTaxonID={rootTaxonID}
          year={year}
          user={user}
          site={site}
          currentUser={currentUser}
        />
        { data && data.growth && (
          <Growth
            data={Object.assign( {}, data.growth, { taxa: data.taxa.accumulation } )}
            year={year}
            site={site && site.id !== DEFAULT_SITE_ID ? site : null}
          />
        ) }
        { window.location.search.match( /test=compare/ ) && data && data.taxa && data.taxa.accumulation && (
          <Compare data={data} year={year} />
        ) }
        { data.publications && (
          <Publications data={data.publications} year={year} />
        ) }
        {
          data.translators
          && ( !site || site.id === DEFAULT_SITE_ID || !_.isEmpty( site.locale ) )
          && (
            <Translators
              data={data.translators}
              siteName={site && site.id !== DEFAULT_SITE_ID ? site.name : null}
            />
          )
        }
        { !user && <Sites year={year} site={site} sites={sites} defaultSiteId={DEFAULT_SITE_ID} /> }
        { !user && ( !site || site.id === DEFAULT_SITE_ID ) && <Donate year={year} /> }
        { updatedAt && (
          <p className="updated-at text-center text-muted">
            { I18n.t( "views.stats.year.stats_generated_datetime", {
              datetime: I18n.localize( "time.formats.long", updatedAt )
            } ) }
          </p>
        ) }
        { user && currentUser && user.id === currentUser.id ? (
          <GenerateStatsButton user={user} year={year} text={I18n.t( "regenerate_stats" )} />
        ) : null }
        <div id="sharing">
          <h2><a name="sharing" href="#sharing"><span>{ I18n.t( "share" ) }</span></a></h2>
          <center>
            <div
              className="fb-share-button"
              data-href={window.location.toString( ).replace( /#.+/, "" )}
              data-layout="button"
              data-size="large"
              data-mobile-iframe="true"
            >
              <a
                // className="fb-xfbml-parse-ignore"
                className="btn btn-primary btn-inat facebook-share-button"
                target="_blank"
                rel="noopener noreferrer"
                href={`https://www.facebook.com/sharer/sharer.php?u=${window.location.toString( ).replace( /#.+/, "" )}&amp;src=sdkpreparse`}
              >
                <img src="/assets/facebook-f-logo-white.svg" alt={I18n.t( "facebook" )} />
                { I18n.t( "facebook" ) }
              </a>
            </div>
            <a
              className="btn btn-primary btn-inat twitter-share-button"
              href={`https://twitter.com/intent/tweet?text=Check+these+${year}+${site.site_name_short || site.name}+stats!&url=${window.location.toString( ).replace( /#.+/, "" )}`}
              data-size="large"
              rel="noopener noreferrer"
            >
              <i className="fa fa-twitter" />
              { I18n.t( "twitter" ) }
            </a>
          </center>
        </div>
      </div>
    );
  }
  let montageObservations = [];
  if (
    data
    && data.observations
    && data.observations.popular
    && data.observations.popular.length > 0
  ) {
    montageObservations = _.filter(
      data.observations.popular, o => (
        o.photos
        && o.photos.length > 0
        && _.filter( o.photos, p => p.original_dimensions ).length > 0
      )
    );
    while ( montageObservations.length < 150 ) {
      montageObservations = montageObservations.concat( montageObservations );
    }
  }
  // https://gist.github.com/59naga/ed6714519284d36792ba
  const isTouchDevice = navigator.userAgent.match(
    /(Android|webOS|iPhone|iPad|iPod|BlackBerry|Windows Phone)/i
  ) !== null;
  return (
    <div id="YearStats">
      <div className={`banner ${user ? "for-user" : ""}`}>
        <div className="montage">
          <div className="photos">
            { _.map( montageObservations, ( o, i ) => (
              <a href={`/observations/${o.id}`} key={`montage-obs-${i}`}>
                <img
                  alt={o.species_guess}
                  src={o.photos[0].url.replace( "square", "thumb" )}
                  width={
                    ( 50 / o.photos[0].original_dimensions.height )
                    * o.photos[0].original_dimensions.width
                  }
                  height={
                    ( 50 / o.photos[0].original_dimensions.height )
                    * o.photos[0].original_dimensions.height
                  }
                />
              </a>
            ) ) }
          </div>
        </div>
        { inatUser ? (
          <div>
            <UserImage user={inatUser} />
            <div className="ribbon-container">
              <div className="ribbon">
                <div className="ribbon-content">
                  { inatUser.name ? `${inatUser.name} (${inatUser.login})` : inatUser.login }
                </div>
              </div>
            </div>
          </div>
        ) : (
          <div className="protector">
            <div className="site-icon">
              <a href={site.url}><img src={site.icon_url} alt={site.name} /></a>
            </div>
            <div className="ribbon-container">
              <div className="ribbon">
                <div className="ribbon-content">
                  <a href={site.url}>{ site.name }</a>
                </div>
              </div>
            </div>
          </div>
        ) }
      </div>
      <Grid fluid={isTouchDevice}>
        <Row>
          <Col xs={12}>
            { user && user.display_donor_since && (
              <center><Donor year={year} user={user} /></center>
            ) }
            <h1>
              {
                I18n.t( "year_in_review", {
                  year
                } )
              }
            </h1>
          </Col>
        </Row>
        <Row>
          <Col xs={12}>
            { body }
            <div id="view-stats-buttons">
              { ( !currentUser || !user || ( user.id !== currentUser.id ) ) && (
                <div>
                  <a href={`/stats/${year}/you`} className="btn btn-primary btn-bordered btn-lg">
                    <i className="fa fa-pie-chart" />
                    { " " }
                    { I18n.t( "view_your_year_stats", { year } ) }
                  </a>
                  { site && defaultSite && site.id !== defaultSite.id && (
                    <div>
                      <a
                        href={`${defaultSite.url}/stats/${year}`}
                        className="btn btn-primary btn-bordered btn-lg"
                      >
                        <i className="fa fa-bar-chart-o" />
                        { " " }
                        { I18n.t( "view_year_stats_for_site", {
                          year,
                          site: defaultSite.name,
                          vow_or_con: "i"
                        } ) }
                      </a>
                    </div>
                  ) }
                </div>
              ) }
              { user && (
                <div>
                  <a href={`/stats/${year}`} className="btn btn-primary btn-bordered btn-lg">
                    <i className="fa fa-bar-chart-o" />
                    { " " }
                    { I18n.t( "view_year_stats_for_site", {
                      year,
                      site: site.name,
                      vow_or_con: site.name[0].toLowerCase( )
                    } ) }
                  </a>
                </div>
              ) }
            </div>
          </Col>
        </Row>
      </Grid>
    </div>
  );
};

App.propTypes = {
  year: PropTypes.number,
  user: PropTypes.object,
  currentUser: PropTypes.object,
  data: PropTypes.object,
  site: PropTypes.object,
  sites: PropTypes.array,
  rootTaxonID: PropTypes.number,
  updatedAt: PropTypes.object
};

export default App;
