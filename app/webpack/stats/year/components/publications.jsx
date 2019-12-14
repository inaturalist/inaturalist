import React from "react";
import PropTypes from "prop-types";
import { Row, Col } from "react-bootstrap";
import _ from "lodash";
import { commasAnd } from "../../../taxa/shared/util";

const Publications = ( { data, year } ) => {
  const renderPublication = pub => {
    const baseKey = `publication-${pub.id}`;
    let authors = `${pub.authors[0].lastName}, ${pub.authors[0].firstName[0]}.`;
    if ( pub.authors.length > 1 ) {
      authors += ", ";
      authors += commasAnd( pub.authors.slice( 1, pub.authors.lengt ).map( a => `${a.lastName}, ${a.firstName[0]}.` ) );
    }
    return (
      <Row key={baseKey}>
        <Col xs={3}>
          <div
            data-badge-popover="right"
            data-badge-type="medium-donut"
            data-doi={pub.identifiers.doi}
            data-hide-no-mentions="true"
            className="altmetric-embed"
          />
        </Col>
        <Col xs={9}>
          <p>
            { authors }
            { pub.year }
            { ". " }
            <a href={pub.websites[0]}>{ `"${pub.title}." ` }</a>
            <i>{ pub.source }</i>
            { ". " }
            { pub._gbifDOIs && (
              <span className="data-dois">
                { I18n.t( "data_used" )}
                { " " }
                { pub._gbifDOIs.map( doi => (
                  <a
                    key={`${baseKey}-${doi}`}
                    href={`https://doi.org/${doi}`}
                  >
                    { doi }
                  </a>
                ) ) }
              </span>
            ) }
          </p>
        </Col>
      </Row>
    );
  };
  let shortDesc = I18n.t( "views.stats.year.publications_desc_short_html", { numStudies: data.count } );
  const shortDescEn = I18n.t( "views.stats.year.publications_desc_short_html", {
    numStudies: data.count,
    locale: "en"
  } );
  if ( I18n.locale !== "en" && shortDesc === shortDescEn ) {
    shortDesc = null;
  }
  const desc = I18n.t( "views.stats.year.publications_desc_html", { numStudies: data.count } );
  return (
    <div className="Publications">
      <h3>
        <a name="publications" href="#publications">
          <span>{I18n.t( "studies_that_used_inaturalist_data_in_year", { year } )}</span>
        </a>
      </h3>
      { shortDesc && (
        <p
          className="text-muted"
          dangerouslySetInnerHTML={{
            __html: shortDesc
          }}
        />
      ) }
      { _.chunk( data.results, 2 ).map( chunk => (
        <Row key={`publications-row-${chunk[0].id}`}>
          { chunk.map( pub => (
            <Col
              xs={12}
              sm={6}
              key={`publication-col-${pub.id}`}
            >
              { renderPublication( pub ) }
            </Col>
          ) ) }
        </Row>
      ) ) }
      <div className="row">
        <div className="xs-col-12">
          { !shortDesc && (
            <p
              className="lead text-center"
              dangerouslySetInnerHTML={{
                __html: desc
              }}
            />
          ) }
          { shortDesc && (
            <center>
              <a href={data.url} className="btn btn-default btn-bordered inlineblock">
                { I18n.t( "view_all" ) }
              </a>
            </center>
          ) }
        </div>
      </div>
    </div>
  );
};

Publications.propTypes = {
  data: PropTypes.object,
  year: PropTypes.number.isRequired
};

Publications.defaultProps = {
  data: {
    results: []
  }
};

export default Publications;
