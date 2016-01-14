When(/^I am on ([^ ]+?)$/) do |path|
  visit path
end

When(/^I click on "(.*?)"$/) do |search|
  click_on search
end

When(/^I click xpath (.*?)$/) do |search|
  find(:xpath, search).click
end

When(/^I type "(.*?)" into "(.*?)"$/) do |text, field|
  fill_in field, with: text
end

Then(/^I should see "(.*?)"$/) do |text|
  page.should have_content(text)
end

Then(/^the page should have css "(.*?)"$/) do |text|
  page.should have_css(text)
end

Then(/^the page should not have css "(.*?)"$/) do |text|
  page.should_not have_css(text)
end

Then(/^the page should have tag "(.*?)" with text "(.*?)"$/) do |tag, text|
  page.should have_tag(tag, text: text)
end

Then(/^I should see the header and footer$/) do
  page.should have_css("body #header #mainnav")
  page.should have_css("body #footer #inatnotice")
end

Then(/^I wait (.*?) seconds?$/) do |seconds|
  sleep seconds.to_f
end

