require 'spec_helper'

describe "sim", vcr: true do
  it "should validate a sitemap index" do
    visit "/"
    fill_in "sitemap_url", with: "http://resync.library.cornell.edu/sim100/resourcelist.xml"
    click_on "Validate"
    expect(page).to have_content "Status OK"
  end
end
