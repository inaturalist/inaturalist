import React from "react";
import PropTypes from "prop-types";
import { Grid, Row, Col } from "react-bootstrap";
import _ from "lodash";

const InteractionsTab = ( { interactions } ) => {
  const interactionsByType = _.groupBy( interactions || [], "interaction_type" );
  const iconicTaxonNames = [
    "Protozoa",
    "Plantae",
    "Fungi",
    "Animalia",
    "Mollusca",
    "Arachnida",
    "Insecta",
    "Amphibia",
    "Reptilia",
    "Aves",
    "Mammalia",
    "Actinopterygii",
    "Chromista"
  ];
  let status;
  if ( !interactions ) {
    status = (
      <h2 className="text-center">
        <i className="fa fa-refresh fa-spin" />
      </h2>
    );
  } else if ( interactions && interactions.length === 0 ) {
    status = (
      <h3 className="text-muted text-center">
        { I18n.t( "no_interaction_data_available" ) }
      </h3>
    );
  }
  return (
    <Grid className="InteractionsTab">
      <Row>
        <Col xs={8}>
          { status }
          <ul>
            { _.map( interactionsByType, ( typedInteractions, type ) => (
              <li key={`interactions-${type}`}>
                <strong>
                  { I18n.t( "label_colon", { label: I18n.t( type, { defaultValue: type } ) } ) }
                  { " " }
                  { I18n.t( "x_species", { count: typedInteractions.length } ) }
                </strong>
                <ul>
                  { typedInteractions.map( interaction => {
                    let iconicTaxonName;
                    if ( interaction.target.path ) {
                      iconicTaxonName = _.last( _.intersection(
                        iconicTaxonNames,
                        interaction.target.path.split( " | " )
                      ) );
                    }
                    iconicTaxonName = iconicTaxonName || "unknown";
                    let rank;
                    if ( interaction.target.name.split( " " ).length > 1 ) {
                      rank = "species";
                    }
                    return (
                      <li key={interaction.target_taxon_external_id}>
                        <a
                          href={
                            `/taxa/${interaction.target.name}?test=interactions#interactions-tab`
                          }
                          className={`taxon ${iconicTaxonName} ${rank}`}
                        >
                          <i className={`icon-iconic-${iconicTaxonName.toLowerCase( )}`} />
                          { " " }
                          <span className="display-name sciname">{ interaction.target.name }</span>
                        </a>
                      </li>
                    );
                  } ) }
                </ul>
              </li>
            ) ) }
          </ul>
        </Col>
        <Col xs={4}>
          <h3>About Interactions</h3>
          <p>
            Most organisms interact with other organisms in some way or
            another, and how they do so usually defines how they fit into an
            ecosystem. These interactions come to us
            from <a href="http://www.globalbioticinteractions.org/">Global Biotic Interactions (GLoBI)</a>,
            a database and webservice that combines
            interaction data from numerous sources, including iNaturalist.
            You can actually contribute to this database by adding the
            "Eating", "Eaten by", and "Host" observation fields to
            observations that demonstrate those interactions.
          </p>
          <h3>Learn More</h3>
          <ul className="tab-links list-group">
            {
              [{
                id: 1,
                url: "http://www.globalbioticinteractions.org",
                host: "globalbioticinteractions.org",
                text: "Global Biotic Interactions (GLoBI)"
              }, {
                id: 2,
                url: "https://en.wikipedia.org/wiki/Biological_interaction",
                host: "en.wikipedia.org",
                text: "About Biological Interactions"
              }].map( link => (
                <li className="list-group-item" key={`status-link-${link.id}`}>
                  <a
                    href={link.url}
                    style={{
                      backgroundImage: `url( 'https://www.google.com/s2/favicons?domain=${link.host}' )`,
                      backgroundRepeat: "no-repeat",
                      padding: "1px 0 1px 25px",
                      backgroundPosition: "0 2px"
                    }}
                  >
                    <i className="glyphicon glyphicon-new-window pull-right" />
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

InteractionsTab.propTypes = {
  interactions: PropTypes.array
};

export default InteractionsTab;
