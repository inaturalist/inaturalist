import React from "react";
import PropTypes from "prop-types";
import { Grid, Row, Col } from "react-bootstrap";

const StoreContent2021 = ( { isTouchDevice } ) => (
  <Grid fluid={isTouchDevice} className="StoreContent2021">
    <Row>
      <Col xs={12}>
        <h3>
          <a name="store" href="#store">
            <span>{I18n.t( "check_out_the_inat_store" )}</span>
          </a>
        </h3>
        <a
          href="https://store.inaturalist.org"
          className="img-link"
        >
          <img
            alt={I18n.t( "store" )}
            src="https://static.inaturalist.org/misc/2021-yir/2021-yir-store.png"
            className="img-responsive"
          />
        </a>
      </Col>
    </Row>
  </Grid>
);

StoreContent2021.propTypes = {
  isTouchDevice: PropTypes.bool
};

export default StoreContent2021;
