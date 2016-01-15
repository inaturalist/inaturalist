@javascript
Feature: Observations

  Scenario: Index
    When I am on /observations
    Then I should see the header and footer
    Then I should see "The World"
    Then the page should have css "#observations-map"
    When I click on "Grid"
    Then the page should have css "#result-grid"
    When I click on "Table"
    Then the page should have css "#result-table"
    When I click xpath //div[@ng-click="changeView('species')"]
    Then the page should have css "#taxa-grid"
    When I click xpath //div[@ng-click="changeView('identifiers')"]
    Then the page should have css "#identifiers-table"
    When I click xpath //div[@ng-click="changeView('observers')"]
    Then the page should have css "#observers-table"

  Scenario: Default Subviews
    When I am on /observations?subview=map
    Then the page should have css "#observations-map"
    When I am on /observations?subview=grid
    Then the page should have css "#result-grid"
    When I am on /observations?subview=table
    Then the page should have css "#result-table"

  Scenario: Default Views
    When I am on /observations?view=species
    Then the page should have css "#taxa-grid"
    When I am on /observations?view=identifiers
    Then the page should have css "#identifiers-table"
    When I am on /observations?view=observers
    Then the page should have css "#observers-table"

  Scenario: Preserving Subview
    When I am on /observations?view=identifiers&subview=grid
    Then the page should have css "#identifiers-table"
    When I click xpath //div[@ng-click="changeView('observations')"]
    Then the page should have css "#result-grid"

  Scenario: Taxon autocomplete
    When I am on /observations
    When I type "Amanita" into "taxon_name"
    Then I wait 1 seconds
    Then the page should have tag ".ac-label .title" with text "Amanita"
    Then the page should have tag ".ac-label .title" with text "Amanitaceae"
    Then the page should have tag ".ac-label .title" with text "Fly Agaric"

  Scenario: Place Searching
    When I am on /observations
    When I type "CO, US" into "place_name"
    When I click on "Go"
    Then I wait 2 seconds
    # TODO: for some reason searching class and text Colorado wasn't working
    Then the page should have css ".geo.selected"
    Then I should see "Colorado"
    Then the page should not have css "button.reload"

  Scenario: Map Toggles
    When I am on /observations
    Then the page should not have css "#layer-control .dropdown-menu"
    Then the page should not have css "button.places .dropdown-menu"
    Then the page should not have css "#obs-container.fullscreen-enabled"
    Then the page should not have css "#map-legend"
    Then the page should not have css "button.reload"
    # Layers
    When I click xpath //div[@id="layer-control"]
    Then the page should have css "#layer-control .dropdown-menu"
    When I click xpath //div[@id="layer-control"]
    Then the page should not have css "#layer-control .dropdown-menu"
    # Places of interest
    When I click on "Places of Interest"
    Then the page should have css "button.places + .dropdown-menu"
    When I click on "Places of Interest"
    Then the page should not have css "button.places + .dropdown-menu"
    # Map legend
    When I click on "Map Legend"
    Then the page should have css "#map-legend"
    When I click on "Map Legend"
    Then the page should not have css "#map-legend"
    # Fullscreen
    When I click on "Full screen"
    Then the page should have css "#obs-container.fullscreen-enabled"
    When I click on "Full screen"
    Then the page should not have css "#obs-container.fullscreen-enabled"
    # Reload search in map
    When I click on "Zoom In"
    Then the page should have css "button.reload"
    When I click on "Redo search in map"
    Then the page should not have css "button.reload"

