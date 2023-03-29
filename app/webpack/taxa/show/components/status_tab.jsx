import React from "react";
import PropTypes from "prop-types";
import ReactDOMServer from "react-dom/server";
import {
  Col,
  Grid,
  OverlayTrigger,
  Popover,
  Row
} from "react-bootstrap";
import _ from "lodash";
import UserText from "../../../shared/components/user_text";
import SplitTaxon from "../../../shared/components/split_taxon";
import { urlForTaxon } from "../../shared/util";

const StatusTab = ( {
  listedTaxa,
  listedTaxaCount,
  statuses,
  taxon
} ) => {
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
            <th>
              <OverlayTrigger
                trigger="click"
                rootClose
                placement="top"
                containerPadding={20}
                overlay={(
                  <Popover id="geoprivacy-explanation">
                    <div className="contents">
                      { I18n.t( "conservation_status_geoprivacy_desc" ) }
                    </div>
                  </Popover>
                )}
                className="cool"
              >
                <span>
                  { I18n.t( "taxon_geoprivacy" ) }
                  { " " }
                  <i className="fa fa-info-circle linky" />
                </span>
              </OverlayTrigger>
            </th>
          </tr>
        </thead>
        <tbody>
          { sortedStatuses.map( status => {
            let text = status.statusText( );
            text = I18n.t( text, { defaultValue: text } );
            if ( !text.match( new RegExp( `(${status.status})` ) ) ) {
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
            let geoprivacy = I18n.t( "open_" );
            if ( status.geoprivacy === "obscured" ) {
              geoprivacy = I18n.t( "obscured" );
            } else if ( status.geoprivacy === "private" ) {
              geoprivacy = I18n.t( "private_" );
            }
            let source = I18n.t( "unknown" );
            if ( status.url && status.authority ) {
              source = (
                <a href={status.url}>{ status.authority }</a>
              );
            } else if ( status.authority ) {
              source = status.authority;
            } else if ( status.user ) {
              source = <a href={`/people/${status.user.login}`}>{ status.user.login }</a>;
            }
            const statusTaxon = _.find(
              taxon.ancestors,
              ancestor => ancestor.id === status.taxon_id
            );
            return (
              <tr
                key={`statuses-${status.authority}-${status.place ? status.place.id : "global"}`}
              >
                <td>
                  <div className="media">
                    <div className="media-left">
                      { status.place
                        ? (
                          <a
                            href={`/places/${status.place ? status.place.id : null}`}
                            className="place-link"
                          >
                            <i className="fa fa-invert fa-map-marker" />
                          </a>
                        )
                        : <i className="fa fa-invert fa-globe" />}
                    </div>
                    <div className="media-body">
                      { status.place
                        ? (
                          <a href={`/places/${status.place.id}`} className="place-link">
                            { I18n.t(
                              `places_name.${_.snakeCase( status.place.display_name )}`,
                              { defaultValue: status.place.display_name }
                            ) }
                          </a>
                        )
                        : I18n.t( "globally" )}
                    </div>
                  </div>
                </td>
                <td>
                  <i className={`glyphicon glyphicon-flag ${flagClass}`} />
                  { " " }
                  { text }
                  { status.description && status.description.length > 0 && (
                    <UserText
                      truncate={550}
                      className="text-muted"
                      text={status.description}
                    />
                  ) }
                  { status.taxon_id && status.taxon_name && status.taxon_id !== taxon.id && (
                    <div
                      className="text-muted"
                      dangerouslySetInnerHTML={{
                        __html: I18n.t( "status_applied_from_higher_level_taxon_html", {
                          taxon: ReactDOMServer.renderToString(
                            <SplitTaxon taxon={statusTaxon} url={urlForTaxon( statusTaxon )} />
                          )
                        } )
                      }}
                    />
                  ) }
                  { status.user && status.created_at && (
                    <div
                      className="small text-muted"
                      dangerouslySetInnerHTML={{
                        __html: I18n.t( "added_by_user_on_date_html", {
                          user: ReactDOMServer.renderToString( <a href={`/people/${status.user.login}`}>{status.user.login}</a> ),
                          date: I18n.localize( "date.formats.month_day_year", status.created_at )
                        } )
                      }}
                    />
                  ) }
                  { status.updater && status.updated_at && (
                    <div
                      className="small text-muted"
                      dangerouslySetInnerHTML={{
                        __html: I18n.t( "updated_by_user_on_date_html", {
                          user: ReactDOMServer.renderToString( <a href={`/people/${status.updater.login}`}>{status.updater.login}</a> ),
                          date: I18n.localize( "date.formats.month_day_year", status.updated_at )
                        } )
                      }}
                    />
                  ) }
                </td>
                <td>
                  <div className="media">
                    <div className="media-body">
                      { source }
                    </div>
                    { status.url && (
                      <div className="media-right">
                        <a href={status.url}>
                          <i className="glyphicon glyphicon-new-window" />
                        </a>
                      </div>
                    ) }
                  </div>
                </td>
                <td>
                  { geoprivacy }
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
      <div>
        { listedTaxaCount > listedTaxa.length ? (
          <p>{ I18n.t( "showing_x_of_y_listings", { x: listedTaxa.length, y: listedTaxaCount } ) }</p>
        ) : null }
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
                      { lt.place
                        ? (
                          <a href={`/places/${lt.place ? lt.place.id : null}`} className="place-link">
                            <i className="fa fa-invert fa-map-marker" />
                          </a>
                        )
                        : <i className="fa fa-invert fa-globe" />}
                    </div>
                    <div className="media-body">
                      { lt.place
                        ? (
                          <a href={`/places/${lt.place ? lt.place.id : null}`} className="place-link">
                            { I18n.t(
                              `places_name.${_.snakeCase( lt.place.name )}`,
                              { defaultValue: lt.place.display_name }
                            ) }
                          </a>
                        )
                        : I18n.t( "globally" )}
                    </div>
                  </div>
                </td>
                <td>
                  { I18n.t( lt.establishment_means, { defaultValue: lt.establishment_means } ) }
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
      </div>
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
                { I18n.t( "views.taxa.show.about_conservation_status_desc" ) }
                { " " }
                <a href="https://en.wikipedia.org/wiki/Conservation_status">
                  { I18n.t( "more__context_conservation_statuses", {
                    defaultValue: I18n.t( "more" )
                  } ) }
                  { " " }
                  <i className="icon-link-external" />
                </a>
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
                      url: "https://explorer.natureserve.org/AboutTheData/Statuses",
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
                        <i className="icon-link-external pull-right" />
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
                { I18n.t( "views.taxa.show.about_establishment_desc" ) }
                <a href="https://dwc.tdwg.org/list/#dwc_establishmentMeans">
                  { I18n.t( "more__context_establishment_means", {
                    defaultValue: I18n.t( "more" )
                  } ) }
                  { " " }
                  <i className="icon-link-external" />
                </a>
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
  listedTaxa: PropTypes.array,
  listedTaxaCount: PropTypes.number,
  taxon: PropTypes.object
};

StatusTab.defaultProps = {
  statuses: [],
  listedTaxa: [],
  listedTaxaCount: 0
};

export default StatusTab;
