import React, { PropTypes } from "react";
import { Grid, Row, Col } from "react-bootstrap";
import _ from "lodash";
import UserText from "../../../shared/components/user_text";

// Things I need from cons statuses
// * place admin_level or ancestry to sort
// * status_text
// * iucn status and name (not just the code)

const StatusTab = ( { statuses } ) => {
  const sortedStatuses = _.sortBy( statuses, status => {
    let sortKey = `-${status.iucn}`;
    if ( status.place ) {
      sortKey = `${status.place.admin_level}-${status.place.name}-${status.iucn}`;
    }
    return sortKey;
  } );
  return (
    <Grid className="StatusTab">
      <Row>
        <Col xs={8}>
          <h2>{ I18n.t( "conservation_status" ) }</h2>
          <table className="table">
            <thead>
              <tr>
                <th>{ I18n.t( "place" ) }</th>
                <th>{ I18n.t( "conservation_status" ) }</th>
                <th>{ I18n.t( "source" ) }</th>
              </tr>
            </thead>
            <tbody>
              { sortedStatuses.map( status => {
                let text = status.statusText( );
                text = I18n.t( text, { defaultValue: text } );
                text = _.capitalize( text );
                if ( !text.match( /\(${status.status}\)/ ) ) {
                  text += ` (${status.status})`;
                }
                let flagClass;
                switch ( status.iucnStatusCode( ) ) {
                  case "LC":
                    flagClass = "text-success";
                    break;
                  case "NT":
                  case "VU":
                    flagClass = "text-warning";
                    break;
                  case "CR":
                  case "EN":
                    flagClass = "text-danger";
                    break;
                  default:
                    // ok
                }
                return (
                  <tr
                    key={`statuses-${status.authority}-${status.place ? status.place.id : "global"}`}
                  >
                    <td>
                      <div className="media">
                        <div className="media-left">
                          <a href={`/places/${status.place ? status.place.id : null}`}>
                            <i className={`fa fa-invert fa-${status.place ? "map-marker" : "globe"}`}></i>
                          </a>
                        </div>
                        <div className="media-body">
                          <a href={`/places/${status.place ? status.place.id : null}`}>
                            { status.place ? status.place.display_name : _.capitalize( I18n.t( "globally" ) ) }
                          </a>
                        </div>
                      </div>
                    </td>
                    <td>
                      <i className={`glyphicon glyphicon-flag ${flagClass}`}>
                      </i> { text }
                      { status.description && status.description.length > 0 ? (
                        <UserText
                          truncate={550}
                          className="text-muted"
                          text={ status.description }
                        />
                      ) : null }
                    </td>
                    <td>
                      { status.url ? (
                        <div className="media">
                          <div className="media-body">
                            <a href={status.url}>
                              { status.authority }
                            </a>
                          </div>
                          <div className="media-right">
                            <a href={`/places/${status.place ? status.place.id : null}`}>
                              <i className="glyphicon glyphicon-new-window"></i>
                            </a>
                          </div>
                        </div>
                      ) : null }
                    </td>
                  </tr>
                );
              } ) }
            </tbody>
          </table>
        </Col>
        <Col xs={4}>
          <h3>{ I18n.t( "about_conservation_status" ) }</h3>
          <p>
            {
              I18n.t( "views.taxa.show.about_conservation_status_desc" )
            } <a
              href="https://en.wikipedia.org/wiki/Conservation_status"
            >{ I18n.t( "more" ) } <i className="glyphicon glyphicon-new-window"></i></a>
          </p>
          <h3>{ I18n.t( "examples_of_ranking_organizations" ) }</h3>
          <ul className="tab-links list-group">
            {
              [
                {
                  id: 1,
                  url: "http://www.iucnredlist.org",
                  host: "iucnredlist.org",
                  text: "International Union for the Conservation of Nature (IUCN)"
                },
                {
                  id: 2,
                  url: "http://explorer.natureserve.org/ranking.htm",
                  host: "explorer.natureserve.org",
                  text: "NatureServe"
                }
              ].map( link => (
                <li className="list-group-item" key={`status-link-${link.id}`}>
                  <a
                    href={link.url}
                    style={{
                      backgroundImage: `url( http://www.google.com/s2/favicons?domain=${link.host} )`,
                      backgroundRepeat: "no-repeat",
                      padding: "1px 0 1px 25px",
                      backgroundPosition: "0 2px"
                    }}
                  >
                    { link.text }
                  </a>
                </li>
              ) )
            }
          </ul>
        </Col>
      </Row>
    </Grid>
  );
};

StatusTab.propTypes = {
  statuses: PropTypes.array
};

export default StatusTab;
