import React from "react";
import PropTypes from "prop-types";
import { Grid, Row, Col } from "react-bootstrap";

/**
 * Renders a button-styled link with the text "View More"
 * if the prop showViewMoreLink is true.
 *
 * Otherwise, renders nothing.
 *
 * Spacing around the link is appropriate for use as a footer.
 *
 */

const ViewMoreFooter = ( { showViewMoreLink, viewMoreUrl } ) => {
    return (showViewMoreLink
        ?
        <div className="ViewMoreFooter">
            <Grid>
                <Row>
                    <Col xs={12} className="text-center">
                        <a href={viewMoreUrl} className={"btn btn-primary btn-inat btn-green"}>{ I18n.t( "view_more" ) }</a>
                    </Col>
                </Row>
            </Grid>
        </div>
        : null);
};

ViewMoreFooter.propTypes = {
    showViewMoreLink: PropTypes.bool,
    viewMoreUrl: PropTypes.string
};

export default ViewMoreFooter;
