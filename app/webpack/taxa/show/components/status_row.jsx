import React, { PropTypes } from "react";
import { Row, Col } from "react-bootstrap";
import StatusHeader from "./status_header";
import EstablishmentHeader from "./establishment_header";

const StatusRow = ( { conservationStatus, establishmentMeans } ) => {
  if ( conservationStatus && establishmentMeans ) {
    return (
      <Row>
        <Col xs={6}>
          <StatusHeader status={conservationStatus} />
        </Col>
        <Col xs={6}>
          <EstablishmentHeader establishmentMeans={establishmentMeans} />
        </Col>
      </Row>
    );
  }
  if ( conservationStatus ) {
    return <Row><Col xs={12}><StatusHeader status={conservationStatus} /></Col></Row>;
  }
  if ( establishmentMeans ) {
    return <Row><Col xs={12}><EstablishmentHeader establishmentMeans={establishmentMeans} /></Col></Row>;
  }
  return <Row />;
};

StatusRow.propTypes = {
  conservationStatus: PropTypes.object,
  establishmentMeans: PropTypes.object
};

export default StatusRow;
