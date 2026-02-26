import React from "react";
import PropTypes from "prop-types";
import LazyLoad from "react-lazy-load";

// Custom lazyload component for the DQA, where we want lazy loading to apply
// inside of the collapsible element
const AssessmentLazyLoad = ( {
  config,
  children
} ) => (
  <LazyLoad
    debounce={false}
    verticalOffset={500}
  >
    { children }
  </LazyLoad>
);

AssessmentLazyLoad.propTypes = {
  children: PropTypes.any,
  config: PropTypes.object
};

export default AssessmentLazyLoad;
