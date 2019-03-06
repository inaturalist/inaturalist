import { render } from "react-dom";
import React from "react";
import StatsYearApp from "./components/app";

/* global YEAR */
/* global DISPLAY_USER */
/* global YEAR_SITE */
/* global YEAR_DATA */
/* global ROOT_TAXON_ID */
render(
  <StatsYearApp
    year={YEAR}
    user={DISPLAY_USER}
    currentUser={CURRENT_USER}
    site={YEAR_SITE}
    data={YEAR_DATA}
    rootTaxonID={ROOT_TAXON_ID}
  />,
  document.getElementById( "app" )
);
