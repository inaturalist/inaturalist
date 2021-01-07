import { render } from "react-dom";
import React from "react";
import StatsYearApp from "./components/app";

/* global YEAR */
/* global DISPLAY_USER */
/* global YEAR_SITE */
/* global SITES */
/* global YEAR_DATA */
/* global ROOT_TAXON_ID */
/* global YEAR_STATISTIC_UPDATED_AT */
render(
  // eslint-disable-next-line react/jsx-filename-extension
  <StatsYearApp
    year={YEAR}
    user={DISPLAY_USER}
    currentUser={CURRENT_USER}
    site={YEAR_SITE}
    sites={SITES}
    data={YEAR_DATA}
    rootTaxonID={ROOT_TAXON_ID}
    updatedAt={YEAR_STATISTIC_UPDATED_AT}
  />,
  document.getElementById( "app" )
);
