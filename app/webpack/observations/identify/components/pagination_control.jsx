import React, { PropTypes } from "react";
import { Button } from "react-bootstrap";
import Pagination from "rc-pagination";

const PaginationControl = ( {
  visible,
  loadMore,
  loadPage,
  perPage,
  current,
  totalResults
} ) => (
  <div className="PaginationControl text-center">
    <Button onClick={loadMore} className={`stacked ${visible ? "" : "collapse"}`}>
      Load More
    </Button>
    <Pagination
      total={totalResults}
      current={current}
      pageSize={perPage}
      locale={ {
        prev_page: "Prev",
        next_page: "Next"
      } }
      onChange={ page => loadPage( page ) }
    />
  </div>
);

PaginationControl.propTypes = {
  visible: PropTypes.bool,
  loadMore: PropTypes.func,
  loadPage: PropTypes.func,
  totalResults: PropTypes.number,
  current: PropTypes.number,
  perPage: PropTypes.number
};

export default PaginationControl;
