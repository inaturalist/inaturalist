import _ from "lodash";
import React from "react";
import PropTypes from "prop-types";
import {
  Col,
  Grid,
  Panel,
  Row
} from "react-bootstrap";
import moment from "moment-timezone";
import TaxonMap from "../../../observations/identify/components/taxon_map";
import { taxonLayerForTaxon } from "../../shared/util";

// Use custom relative times for moment
const shortRelativeTime = I18n.t( "momentjs" ) ? I18n.t( "momentjs" ).shortRelativeTime : null;
const relativeTime = {
  ...I18n.t( "momentjs", { locale: "en" } ).shortRelativeTime,
  ...shortRelativeTime
};
moment.locale( I18n.locale );
moment.updateLocale( moment.locale( ), { relativeTime } );

const IdentificationsTab = ( {
  response,
  identificationsQuery,
  setIdentificationsQuery,
  updateCurrentUser,
  bounds,
  latitude,
  longitude,
  zoomLevel,
  config,
  taxon,
  currentUser,
  voteIdentification,
  unvoteIdentification
} ) => {
  let content;
  const isAdmin = currentUser?.roles.indexOf( "admin" ) >= 0;
  if ( !isAdmin ) {
    return content;
  }
  const allAttributeValues = [];
  if ( response?.results.length > 0 ) {
    content = response.results.map( result => {
      let annotations;
      if ( !_.isEmpty( result.observation.annotations ) ) {
        annotations = (
          <div className="annotations">
            {result.observation.annotations.map( annotation => {
              allAttributeValues.push( {
                term: annotation.controlled_attribute,
                value: annotation.controlled_value
              } );
              return (
                <button
                  type="button"
                  className="btn btn-default btn-sm"
                  key={annotation.uuid}
                  onClick={( ) => {
                    setIdentificationsQuery( {
                      ...identificationsQuery,
                      term_value_id: annotation.controlled_value.id
                    } );
                    $( "html, body" ).animate( {
                      scrollTop: $( ".IdentificationsTab" ).offset( ).top
                    }, 100 );
                  }}
                >
                  {annotation.controlled_attribute.label }
                  :&nbsp;
                  {annotation.controlled_value.label}
                </button>
              );
            } )}
          </div>
        );
      }
      let img;
      if ( result.observation.photos.length > 0 ) {
        const photo = result.observation.photos[0];
        img = (
          <div
            className="image"
            style={{
              backgroundImage: `url('${photo.photoUrl( "medium" )}')`
            }}
          />
        );
      }
      const time = (
        <time
          className="time"
          dateTime={result.created_at}
          title={moment( result.created_at ).format( I18n.t( "momentjs.datetime_with_zone" ) )}
        >
          <a
            href={`/identifications/${result.id}`}
          >
            {moment.parseZone( result.created_at ).fromNow( )}
          </a>
        </time>
      );
      const votesFor = [];
      let userVotedFor;
      _.each( result.votes, v => {
        if ( v.vote_flag === true ) {
          votesFor.push( v );
        }
        if ( v.user?.id === config.currentUser.id ) {
          userVotedFor = ( v.vote_flag === true );
        }
      } );
      const voteAction = () => (
        userVotedFor ? unvoteIdentification( result.uuid ) : voteIdentification( result.uuid )
      );
      const agreeClass = userVotedFor ? "fa-thumbs-up" : "fa-thumbs-o-up";
      return (
        <div
          key={`identification-${result.id}`}
          className="Identification"
        >
          <div className="contents">
            <div className="preview">
              <a href={`/observations/${result.observation.id}`}>
                {img}
              </a>
            </div>
            <div className="content">
              <Panel>
                <Panel.Heading>
                  <Panel.Title>
                    <a href={`/identifications/${result.id}`}>
                      <b>{result.user.login}</b>
                    </a>
                    &nbsp;added an ID tip
                    {time}
                  </Panel.Title>
                </Panel.Heading>
                <Panel.Body>
                  <div className="body">
                    {result.body}
                  </div>
                  <div className="votes">
                    <button
                      type="button"
                      className="btn btn-nostyle"
                      onClick={voteAction}
                      aria-label={I18n.t( "agree_" )}
                      title={I18n.t( "agree_" )}
                    >
                      <i className={`fa ${agreeClass}`} />
                    </button>
                    { !_.isEmpty( votesFor ) && (
                      <span className="vote-count">
                        { votesFor.length }
                      </span>
                    ) }
                  </div>
                </Panel.Body>
                { !_.isEmpty( votesFor ) && (
                  <Panel.Footer>
                    <b>{_.first( votesFor ).user.login}</b>
                    &nbsp;marked this as an ID tip
                    <time
                      className="time"
                      dateTime={_.first( votesFor ).created_at}
                      title={moment( _.first( votesFor ).created_at ).format( I18n.t( "momentjs.datetime_with_zone" ) )}
                    >
                      {moment.parseZone( _.first( votesFor ).created_at ).fromNow( )}
                    </time>
                  </Panel.Footer>
                ) }
              </Panel>
              {annotations}
            </div>
          </div>
        </div>
      );
    } );
  }
  const uniqueAttributeValues = _.sortBy(
    _.uniqBy( allAttributeValues, "value.id" ),
    ["term.label", "value.label"]
  );
  const orderByFields = [
    { value: "votes", label: "Votes" },
    { value: "created_at", label: "date_added" },
    { value: "word_count", label: "Word Count" }
  ];
  return (
    <Grid className="IdentificationsTab">
      <Row>
        <Col xs={8}>
          <h2>
            {I18n.t( "identifications" )}
            &nbsp;(
            {response?.total_results}
            )
          </h2>
          <form
            className="search"
            onSubmit={e => {
              setIdentificationsQuery( {
                ...identificationsQuery,
                q: $( e.target ).find( "[name='q']" ).val( )
              } );
              e.preventDefault( );
            }}
          >
            <div className="input-group">
              <input
                className="form-control"
                name="q"
                type="text"
                placeholder="Search Identifications"
              />
              <span className="input-group-btn">
                <input
                  type="submit"
                  className="btn btn-primary"
                  value="Search"
                />
              </span>
              <span className="input-group-btn">
                <input
                  type="button"
                  className="btn btn-primary"
                  value="Reset"
                  onClick={( ) => {
                    setIdentificationsQuery( { } );
                  }}
                />
              </span>
              <select
                className="form-control"
                onChange={e => {
                  setIdentificationsQuery( {
                    ...identificationsQuery,
                    order_by: e.target.value
                  } );
                }}
                value={identificationsQuery.order_by || "votes"}
              >
                { orderByFields.map( field => (
                  <option value={field.value} key={`params-order-by-${field.value}`}>
                    { I18n.t( field.label, { defaultValue: field.label } ) }
                  </option>
                ) ) }
              </select>
              <select
                className="form-control order"
                onChange={e => {
                  setIdentificationsQuery( {
                    ...identificationsQuery,
                    order: e.target.value
                  } );
                }}
                value={identificationsQuery.order || "desc"}
              >
                <option value="asc">
                  Asc
                </option>
                <option value="desc">
                  Desc
                </option>
              </select>
            </div>
            { !_.isEmpty( uniqueAttributeValues ) && (
              <div className="annotation-search">
                { uniqueAttributeValues.map( termValue => (
                  <button
                    type="button"
                    className="btn btn-default btn-sm"
                    key={`term-${termValue.term.id}-value-${termValue.value.id}`}
                    onClick={( ) => {
                      setIdentificationsQuery( {
                        ...identificationsQuery,
                        term_value_id: termValue.value.id
                      } );
                    }}
                  >
                    {termValue.term.label }
                    :&nbsp;
                    {termValue.value.label}
                  </button>
                ) ) }
              </div>
            ) }
          </form>
          { content }
        </Col>
        <Col xs={4}>
          <Row>
            <div className="taxon-map-container">
              <TaxonMap
                placement="taxa-show-identifications"
                showAllLayer={false}
                minZoom={1}
                gbifLayerLabel={I18n.t( "maps.overlays.gbif_network" )}
                taxonLayers={[
                  taxonLayerForTaxon( taxon, {
                    currentUser: config.currentUser,
                    updateCurrentUser
                  } )
                ]}
                minX={bounds ? bounds.swlng : null}
                minY={bounds ? bounds.swlat : null}
                maxX={bounds ? bounds.nelng : null}
                maxY={bounds ? bounds.nelat : null}
                latitude={latitude}
                longitude={longitude}
                zoomLevel={zoomLevel}
                gestureHandling="auto"
                currentUser={config.currentUser}
                updateCurrentUser={updateCurrentUser}
                reloadKey={`taxa-show-identifications-map-${taxon.id}${bounds ? "-bounds" : ""}`}
                showLegend
              />
            </div>
          </Row>
        </Col>
      </Row>
    </Grid>
  );
};

IdentificationsTab.propTypes = {
  response: PropTypes.object,
  identificationsQuery: PropTypes.object,
  setIdentificationsQuery: PropTypes.func,
  updateCurrentUser: PropTypes.func,
  config: PropTypes.object,
  currentUser: PropTypes.object,
  bounds: PropTypes.object,
  latitude: PropTypes.number,
  longitude: PropTypes.number,
  zoomLevel: PropTypes.number,
  taxon: PropTypes.object,
  voteIdentification: PropTypes.func,
  unvoteIdentification: PropTypes.func
};

export default IdentificationsTab;
