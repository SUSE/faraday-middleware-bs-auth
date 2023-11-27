# frozen_string_literal: true

require "spec_helper"

RSpec.describe Faraday::Middlewares::BuildService do
  it "has a version number" do
    expect(Faraday::Middlewares::BuildService::VERSION).not_to be nil
  end
end
