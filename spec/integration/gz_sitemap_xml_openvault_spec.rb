require 'spec_helper'

describe "openvault", vcr: true do
  it "should validate" do
    visit "/"
    fill_in "sitemap_url", with: "http://openvault.wgbh.org/sitemap.xml.gz"
    click_on "Validate"
    expect(page).to have_content "Status OK"
  end
end
