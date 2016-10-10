import React, { PropTypes } from "react";
import { Grid, Row, Col } from "react-bootstrap";
import UserText from "../../../shared/components/user_text";

const NamesTab = ( { taxon, names } ) => (
  <Grid className="NamesTab">
    <Row>
      <Col xs={8}>
        <table className="table table-striped">
          <thead>
            <tr>
              <th>{ I18n.t( "language_slash_type" ) }</th>
              <th>{ I18n.t( "name" ) }</th>
              <th>{ I18n.t( "action" ) }</th>
            </tr>
          </thead>
          <tbody>
            { names.map( n => (
              <tr key={`taxon-names-${n.id}`}>
                <td>
                  { n.lexicon }
                </td>
                <td
                  className={ n.lexicon.toLowerCase( ).match( /scientific/ ) ? "sciname" : null }
                >
                  { n.name }
                </td>
                <td><a href={`/taxon_names/${n.id}/edit`}>{ I18n.t( "edit" ) }</a></td>
              </tr>
            ) ) }
          </tbody>
        </table>
      </Col>
      <Col xs={4}>
        <ul className="tab-links list-group">
          <li className="list-group-item">
            <a href={`/taxa/${taxon.id}/names`} rel="nofollow">
              <i className="fa fa-gear"></i>
              { I18n.t( "manage_names" ) }
            </a>
          </li>
          <li className="list-group-item">
            <a
              href={`/taxa/${taxon.id}/taxon_names/new`}
              rel="nofollow"
            >
              <i className="fa fa-plus"></i>
              { I18n.t( "add_a_name" ) }
            </a>
          </li>
        </ul>

        <h3>{ I18n.t( "about_names" ) }</h3>
        <UserText text={I18n.t( "views.taxa.show.about_names_desc" )} truncate={400} />
      </Col>
    </Row>
  </Grid>
);

NamesTab.propTypes = {
  taxon: PropTypes.object,
  names: PropTypes.array
};

NamesTab.defaultProps = {
  taxon: {},
  names: []
};

export default NamesTab;
