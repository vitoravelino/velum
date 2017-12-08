require "rails_helper"

describe "Login feature" do
  let!(:user) { create(:user) }

  before do
    visit new_user_session_path
  end

  it "does not show any flash when accessing for the first time" do
    visit root_path
    expect(page).not_to have_content("You need to sign in or sign up before continuing.")
  end

  it "Existing user is able using his login and password to login into velum" do
    # We don't use Capybara's `login_as` method on purpose, because we are
    # testing the UI for logging in.
    fill_in "user_email", with: user.email
    fill_in "user_password", with: user.password
    click_button("Log in")

    expect(page).to have_content("Configuration")
  end

  it "Wrong password results in an error message" do
    pending("fix the validations")
    fill_in "user_email", with: "foo"
    fill_in "user_password", with: "bar"
    find("input[type=submit]", match: :first).click

    expect(page).to have_content("Invalid Email or password")
  end

  it "When guest tries to access dashboard - he is redirected to the login page" do
    visit root_path
    expect(page).to have_content("Log in")
  end

  it "User is redirected to the login page when trying to access a protected page" do
    visit setup_path
    expect(page).to have_content("You need to sign in or sign up before continuing.")
  end

  it "Successful login when trying to access a page redirects back the guest" do
    visit setup_path

    fill_in "user_email", with: user.email
    fill_in "user_password", with: user.password
    click_button("Log in")

    expect(page).to have_current_path(setup_path)
  end
end
