require 'spec_helper'

describe "bbc", vcr: true do
  it "should validate a sitemap index" do
    visit "/"
    fill_in "sitemap_url", with: "http://www.bbc.co.uk/sitemap.xml"
    click_on "Validate"
    expect(page).to have_content "Status OK"
    expect(page).to have_content "http://www.bbc.co.uk/news/sitemap.xml"
  end
  
  it "should validate a sitemap url set" do
    visit "/"
    fill_in "sitemap_url", with: "http://www.bbc.co.uk/news/sitemap.xml"
    click_on "Validate"
    expect(page).to have_content "Status OK"
    expect(page).to have_content "http://www.bbc.co.uk/news/science-environment-27039710"
  end
 end
