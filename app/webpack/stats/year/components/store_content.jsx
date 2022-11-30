import React from "react";
import PropTypes from "prop-types";
import { Grid, Row, Col } from "react-bootstrap";

const StoreContent = ( { isTouchDevice } ) => (
  <Grid fluid={isTouchDevice} className="store">
    <Row>
      <Col xs={12}>
        <a
          href="https://store.inaturalist.org"
          className="img-link"
        >
          <img
            alt={I18n.t( "store" )}
            src="https://static.inaturalist.org/misc/yir-inat-shirts-2020.png"
            className="img-responsive"
          />
        </a>
        <div className="prompt">
          <p>{I18n.t( "views.stats.year.store_prompt" )}</p>
          <a
            href="https://store.inaturalist.org"
            className="btn btn-default btn-donate btn-bordered"
          >
            <i className="fa fa-shopping-cart" />
            { I18n.t( "store_caps", { defaultValue: I18n.t( "store" ) } ) }
          </a>
        </div>
      </Col>
    </Row>
  </Grid>
);

StoreContent.propTypes = {
  isTouchDevice: PropTypes.bool
};

export default StoreContent;
