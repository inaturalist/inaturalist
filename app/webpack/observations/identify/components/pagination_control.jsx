import React from "react";
import PropTypes from "prop-types";
import { Button } from "react-bootstrap";
import Pagination from "rc-pagination";
import MarkAllAsReviewedButtonContainer from "../containers/mark_all_as_reviewed_button_container";

const PaginationControl = ( {
  loadMoreVisible,
  paginationVisible,
  loadMore,
  loadPage,
  perPage,
  current,
  totalResults,
  reviewing
} ) => (
  <div
    className={
      `PaginationControl text-center ${totalResults <= perPage ? "collapse" : ""}`
    }
  >
    <div className="view-more-reviewed stacked">
      <Button
        onClick={loadMore}
        className={loadMoreVisible ? "" : "collapse"}
        disabled={reviewing}
      >
        { I18n.t( "view_more" ) }
      </Button>
      <MarkAllAsReviewedButtonContainer />
    </div>
    <Pagination
      className={paginationVisible ? "" : "collapse"}
      total={totalResults}
      current={current}
      pageSize={perPage}
      locale={{
        prev_page: I18n.t( "previous_page_short" ),
        next_page: I18n.t( "next_page_short" )
      }}
      onChange={page => loadPage( page )}
    />
  </div>
);

PaginationControl.propTypes = {
  loadMoreVisible: PropTypes.bool,
  paginationVisible: PropTypes.bool,
  loadMore: PropTypes.func,
  loadPage: PropTypes.func,
  totalResults: PropTypes.number,
  current: PropTypes.number,
  perPage: PropTypes.number,
  reviewing: PropTypes.bool
};

export default PaginationControl;
