import { render } from "react-dom";
import React from "react";
import StatsYearApp from "./components/app";

render(
  <StatsYearApp
    year={ YEAR }
    user={ DISPLAY_USER }
    currentUser={ CURRENT_USER }
    site={ SITE }
    data={ YEAR_DATA }
  />,
  document.getElementById( "app" )
);
