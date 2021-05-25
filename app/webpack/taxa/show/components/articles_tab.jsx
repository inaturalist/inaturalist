import React from "react";
import PropTypes from "prop-types";
import { Grid, Row, Col } from "react-bootstrap";
import _ from "lodash";

const ArticlesTab = ( {
  taxonId,
  description,
  descriptionSource,
  descriptionSourceUrl,
  links,
  currentUser
} ) => {
  const isCurator = currentUser && currentUser.roles && (
    currentUser.roles.indexOf( "curator" ) >= 0
    || currentUser.roles.indexOf( "admin" ) >= 0
  );
  return (
    <Grid className="ArticlesTab">
      <Row>
        <Col xs={8}>
          <h2
            className={`text-center ${description ? "hidden" : ""}`}
          >
            <i className="fa fa-refresh fa-spin" />
          </h2>
          <div className={description ? "" : "hidden"}>
            <h2>
              { I18n.t( "source_" ) }
              { " " }
              { descriptionSource }
              { " " }
              { descriptionSourceUrl && (
                <a href={descriptionSourceUrl}>
                  <i className="icon-link-external" />
                </a>
              ) }
            </h2>
            <div dangerouslySetInnerHTML={{ __html: description }} />
          </div>
        </Col>
        <Col xs={3} xsOffset={1}>
          <h2>{ I18n.t( "more_info_title" ) }</h2>
          <ul className="list-group iconified-list-group">
            { _.sortBy( links, l => _.lowerCase( l.taxon_link.site_title ) ).map( link => {
              const host = link.url.split( "/" )[2];
              return (
                <li
                  key={`taxon-links-${link.taxon_link.id}`}
                  className="list-group-item"
                >
                  <a
                    href={link.url}
                    style={{
                      backgroundImage: `url( 'https://www.google.com/s2/favicons?domain=${host}' )`
                    }}
                  >
                    { link.taxon_link.site_title }
                  </a>
                  { isCurator ? (
                    <a href={`/taxon_links/${link.taxon_link.id}/edit`}>
                      <i className="fa fa-pencil" />
                    </a>
                  ) : null }
                </li>
              );
            } ) }
          </ul>
          { isCurator ? (
            <a
              href={`/taxon_links/new?taxon_id=${taxonId}`}
              className="btn btn-primary btn-block"
            >
              <i className="icon-link" />
              { " " }
              { I18n.t( "add_link" ) }
            </a>
          ) : null }
        </Col>
      </Row>
    </Grid>
  );
};

ArticlesTab.propTypes = {
  taxonId: PropTypes.number,
  description: PropTypes.string,
  descriptionSource: PropTypes.string,
  descriptionSourceUrl: PropTypes.string,
  links: PropTypes.array,
  currentUser: PropTypes.object
};

ArticlesTab.defaultProps = { links: [] };

export default ArticlesTab;
