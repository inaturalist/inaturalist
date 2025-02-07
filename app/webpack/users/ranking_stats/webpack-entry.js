import "core-js/stable";
import "regenerator-runtime/runtime";
import { render } from "react-dom";
import React from "react";
import SpeciesTableApp from "./components/app";

/* global RANKING_STATS_DATA */
let stats_data = RANKING_STATS_DATA;

render(
  // eslint-disable-next-line react/jsx-filename-extension
  <SpeciesTableApp 
    stats_data={stats_data}
    currentUser={CURRENT_USER} />,
  document.getElementById( "app" )
);
