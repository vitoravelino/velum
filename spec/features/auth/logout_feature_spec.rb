require "rails_helper"

describe "Logout feature" do
  let!(:user) { create(:user) }

  before do
    login user
  end

  it "Redirects to login screen" do
    click_link("Logout")
    expect(page).to have_content("Log in")
  end

  it "After login guest redirects to login page when he attempts to access dashboard again" do
    click_link("Logout")
    visit root_url
    expect(page).to have_content("Log in")
  end
end
