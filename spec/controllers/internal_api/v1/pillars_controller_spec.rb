require "rails_helper"

RSpec.describe InternalApi::V1::PillarsController, type: :controller do
  include ApiHelper

  render_views

  before do
    http_login
    request.accept = "application/json"
  end

  describe "GET /pillar" do
    it "retrieves the pillar contents" do
      get :show
      expect(response.status).to eq 200
    end
  end

end
