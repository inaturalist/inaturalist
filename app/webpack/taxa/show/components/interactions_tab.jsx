import React, { PropTypes } from "react";
import { Grid, Row, Col } from "react-bootstrap";
import _ from "lodash";
import InteractionsForceDirectedGraph from "./interactions_force_directed_graph";
import SplitTaxon from "../../../shared/components/split_taxon";
import { urlForTaxon } from "../../shared/util";

const InteractionsTab = ( { nodes, links, taxon } ) => {
  const interactionsByType = _.groupBy( links || [], "type" );
  let status;
  if ( !nodes ) {
    status = (
      <h2 className="text-center">
        <i className="fa fa-refresh fa-spin"></i>
      </h2>
    );
  } else if ( nodes && nodes.length === 0 ) {
    status = (
      <h3 className="text-muted text-center">
        { I18n.t( "no_interaction_data_available" ) }
      </h3>
    );
  }
  let nodesById = { };
  if ( nodes ) {
    nodesById = _.keyBy( nodes, n => n.id );
  }
  return (
    <Grid className="InteractionsTab">
      <Row>
        <Col xs={8}>
          { status }
          <InteractionsForceDirectedGraph nodes={nodes} links={links} taxon={taxon} />
          <ul>
            { _.map( interactionsByType, ( typedInteractions, type ) => (
              <li key={`interactions-${type}`}>
                <strong>
                  { _.startCase( type ) }: { I18n.t( "x_species", { count: typedInteractions.length } ) }
                </strong>
                <ul>
                  { _.filter( typedInteractions, i => (
                    i.sourceId === taxon.id
                  ) ).map( interaction => {
                    const targetTaxon = nodesById[interaction.targetId];
                    return (
                      <li key={`interaction-table-target-${targetTaxon.id}`}>
                        <SplitTaxon taxon={targetTaxon} showIcon url={urlForTaxon( targetTaxon ) } />
                        { interaction.url ? (
                          <a href={interaction.url} target="_blank">View Interactions</a>
                        ) : null }
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
            ecosystem. These intereactions come to us
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
                      backgroundImage: `url( https://www.google.com/s2/favicons?domain=${link.host} )`,
                      backgroundRepeat: "no-repeat",
                      padding: "1px 0 1px 25px",
                      backgroundPosition: "0 2px"
                    }}
                  >
                    <i className="glyphicon glyphicon-new-window pull-right"></i>
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
  nodes: PropTypes.array,
  links: PropTypes.array,
  taxon: PropTypes.object
};

export default InteractionsTab;
