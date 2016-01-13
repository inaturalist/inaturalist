@javascript
Feature: Home page

  Scenario: Home page text
    When I am on /
    Then I should see the header and footer
    Then I should see "How It Works"
