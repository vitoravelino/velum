require "rails_helper"

RSpec.describe Auth::RegistrationsController, type: :controller do
  let(:user) { create(:user) }

  before { request.env["devise.mapping"] = Devise.mappings[:user] }

  describe "GET /" do
    it "gets the root page properly" do
      get :new
      expect(response.status).to eq 200
    end
  end
end
