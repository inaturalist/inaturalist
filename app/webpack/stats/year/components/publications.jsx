import React from "react";
import PropTypes from "prop-types";
import { Row, Col } from "react-bootstrap";
import _ from "lodash";
import { commasAnd } from "../../../taxa/shared/util";

function authorName( author ) {
  if ( !author.firstName ) return author.lastName;
  return `${author.lastName}, ${author.firstName[0]}.`;
}

const Publications = ( { data, year } ) => {
  const renderPublication = pub => {
    const baseKey = `publication-${pub.id}`;
    let authors = "";
    if ( pub && pub.authors && pub.authors.length > 0 ) {
      authors = authorName( pub.authors[0] );
    }
    if ( pub && pub.authors && pub.authors.length > 1 ) {
      authors += ", ";
      authors += commasAnd(
        pub.authors
          .slice( 1, pub.authors.length )
          .map( authorName )
      );
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
          <div className="publication stacked">
            <div className="authors">
              { authors }
            </div>
            <a className="title" href={pub.websites[0]}>{ pub.title }</a>
            <i className="source">{ pub.source }</i>
            { pub._gbifDOIs && (
              <div className="data-dois">
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
              </div>
            ) }
          </div>
        </Col>
      </Row>
    );
  };
  return (
    <div className="Publications">
      <h3>
        <a name="publications" href="#publications">
          <span>{I18n.t( "studies_that_used_inaturalist_data_in_year", { year } )}</span>
        </a>
      </h3>
      <p
        className="text-muted"
        dangerouslySetInnerHTML={{
          __html: I18n.t( "views.stats.year.publications_desc_short_html", { numStudies: data.count } )
        }}
      />
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
          <center>
            <a href={data.url} className="btn btn-default btn-bordered inlineblock">
              { I18n.t( "view_all_caps", { defaultValue: I18n.t( "view_all" ) } ) }
            </a>
          </center>
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
