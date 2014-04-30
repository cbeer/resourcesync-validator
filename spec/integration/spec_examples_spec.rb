require 'spec_helper'

describe "spec examples" do
  shared_examples "content from file" do
    before :each do
      visit "/"
      click_on 'Paste text'
      fill_in 'input-editor', with: content
      click_on 'Validate Source'
    end
    
    it "should be valid" do
      expect(page).to have_no_selector '.label-danger'
    end
  end
  
  Dir.glob(File.expand_path('../../fixtures/*_sitemap.xml', __FILE__)).each do |d|
    describe d do
      let(:content) { File.read(d) }
      it_behaves_like "content from file"
    end
  end
end
