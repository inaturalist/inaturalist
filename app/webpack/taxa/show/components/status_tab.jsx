import React, { PropTypes } from "react";
import { Grid, Row, Col } from "react-bootstrap";
import _ from "lodash";
import UserText from "../../../shared/components/user_text";

const StatusTab = ( { statuses, listedTaxa } ) => {
  const sortedStatuses = _.sortBy( statuses, status => {
    let sortKey = `-${status.iucn}`;
    if ( status.place ) {
      sortKey = `${status.place.admin_level}-${status.place.name}-${status.iucn}`;
    }
    return sortKey;
  } );
  const sortedListedTaxa = _.sortBy( listedTaxa, lt => {
    let sortKey = "-";
    if ( lt.place ) {
      sortKey = `${lt.place.admin_level}-${lt.place.name}`;
    }
    return sortKey;
  } );
  let statusSection;
  if ( statuses.length > 0 ) {
    statusSection = (
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
                flagClass = "least-concern";
                break;
              case "NT":
              case "VU":
                flagClass = "vulnerable";
                break;
              case "CR":
              case "EN":
                flagClass = "endangered";
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
                      { status.place ?
                        <a
                          href={`/places/${status.place ? status.place.id : null}`}
                          className="place-link"
                        >
                          <i className="fa fa-invert fa-map-marker"></i>
                        </a>
                        :
                        <i className="fa fa-invert fa-globe"></i>
                      }
                    </div>
                    <div className="media-body">
                      { status.place ?
                        <a href={`/places/${status.place.id}`} className="place-link">
                          { I18n.t( `places_name.${_.snakeCase( status.place.display_name )}`,
                            { defaultValue: status.place.display_name } ) }
                        </a>
                        :
                        _.capitalize( I18n.t( "globally" ) )
                      }
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
    );
  }
  let establishmentSection;
  if ( sortedListedTaxa.length > 0 ) {
    establishmentSection = (
      <table className="table">
        <thead>
          <tr>
            <th>{ I18n.t( "place" ) }</th>
            <th>{ I18n.t( "establishment_means" ) }</th>
            <th>{ I18n.t( "source_list_" ) }</th>
            <th>{ I18n.t( "details" ) }</th>
          </tr>
        </thead>
        <tbody>
          { sortedListedTaxa.map( lt => (
            <tr
              key={`listed-taxon-${lt.id}`}
            >
              <td className="conservation-status">
                <div className="media">
                  <div className="media-left">
                    { lt.place ?
                      <a href={`/places/${lt.place ? lt.place.id : null}`} className="place-link">
                        <i className="fa fa-invert fa-map-marker"></i>
                      </a>
                      :
                      <i className="fa fa-invert fa-globe"></i>
                    }
                  </div>
                  <div className="media-body">
                    { lt.place ?
                      <a href={`/places/${lt.place ? lt.place.id : null}`} className="place-link">
                        { I18n.t( `places_name.${_.snakeCase( lt.place.name )}`,
                          { defaultValue: lt.place.name } ) }
                      </a>
                      :
                      _.capitalize( I18n.t( "globally" ) )
                    }
                  </div>
                </div>
              </td>
              <td>
                { _.capitalize( I18n.t( lt.establishment_means,
                  { defaultValue: lt.establishment_means } ) ) }
              </td>
              <td>
                <a href={`/lists/${lt.list.id}`}>{ lt.list.title }</a>
              </td>
              <td>
                <a href={`/listed_taxa/${lt.id}`}>{ I18n.t( "view" ) }</a>
              </td>
            </tr>
          ) ) }
        </tbody>
      </table>
    );
  }
  return (
    <Grid className="StatusTab">
      <Row className="conservation-status tab-section">
        <Col xs={12}>
          <Row>
            <Col xs={8}>
              <h3>{ I18n.t( "conservation_status" ) }</h3>
              { statusSection || I18n.t( "we_have_no_conservation_status_for_this_taxon" ) }
            </Col>
            <Col xs={4}>
              <h4>{ I18n.t( "about_conservation_status" ) }</h4>
              <p>
                {
                  I18n.t( "views.taxa.show.about_conservation_status_desc" )
                } <a
                  href="https://en.wikipedia.org/wiki/Conservation_status"
                >{ I18n.t( "more" ) } <i className="icon-link-external"></i></a>
              </p>
              <h4>{ I18n.t( "examples_of_ranking_organizations" ) }</h4>
              <ul className="tab-links list-group iconified-list-group">
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
                          backgroundImage: `url( 'https://www.google.com/s2/favicons?domain=${link.host}' )`
                        }}
                      >
                        <i className="icon-link-external pull-right"></i>
                        { link.text }
                      </a>
                    </li>
                  ) )
                }
              </ul>
            </Col>
          </Row>
        </Col>
      </Row>
      <Row className="establishment-means tab-section">
        <Col xs={12}>
          <Row>
            <Col xs={8}>
              <h3>{ I18n.t( "establishment_means" ) }</h3>
              { establishmentSection || I18n.t( "we_have_no_establishment_data_for_this_taxon" ) }
            </Col>
            <Col xs={4}>
              <h4>{ I18n.t( "about_establishment_means" ) }</h4>
              <p>
                {
                  I18n.t( "views.taxa.show.about_establishment_desc" )
                } <a
                  href="https://en.wikipedia.org/wiki/Conservation_status"
                >{ I18n.t( "more" ) } <i className="icon-link-external"></i></a>
              </p>
            </Col>
          </Row>
        </Col>
      </Row>
    </Grid>
  );
};

StatusTab.propTypes = {
  statuses: PropTypes.array,
  listedTaxa: PropTypes.array
};

StatusTab.defaultProps = {
  statuses: [],
  listedTaxa: []
};

export default StatusTab;
