# frozen_string_literal: true

require "spec_helper"

RSpec.describe Faraday::Middlewares::BuildService::Authentication do
  let(:base_url) { "http://test.local/" }
  let(:credentials) { {} }

  let(:conn) do
    Faraday.new(url: base_url) do |b|
      b.use described_class, credentials: credentials
    end
  end

  describe "Not authentication needed" do
    subject(:response) { conn.get(base_url + "/auth-echo") }

    before do
      stub_request(:get, base_url + "/auth-echo")
        .to_return(body: "success", status: 200)
    end

    it "performs the request" do
      # heads up: response is not a rails response, it's a Faraday::Response object.
      expect(response.status).to eq(200) # rubocop:disable RSpec/Rails/HaveHttpStatus
      expect(response.body).to eq("success")
    end
  end

  describe "Basic authentication needed" do
    subject(:response) { conn.get(base_url + "/auth-echo") }

    let(:credentials) do
      {
        username: "foo",
        password: "bar"
      }
    end

    before do
      # Fail the first request with Auth basic
      # Check the second for user/password
      stub_request(:get, base_url + "/auth-echo")
        .to_return(
          {
            body: "authenticate",
            status: 401,
            headers: {"www-authenticate": %(Basic realm="Use your SUSE developer account")}
          },
          {
            body: ->(request) { request.headers["Authorization"] },
            status: 200
          }
        )
    end

    it "performs the request" do
      # heads up: response is not a rails response, it's a Faraday::Response object.
      expect(response.status).to eq(200) # rubocop:disable RSpec/Rails/HaveHttpStatus
      expected = %(Basic #{Base64.encode64("foo:bar").strip})
      expect(response.body).to eq(expected)
    end

    context "when follow up requests are done" do
      before do
        # heads-up: stub_request will overwrite stubs if they match perfectly
        #           see: https://github.com/bblimke/webmock
        stub_request(:get, base_url + "/auth-echo")
          .to_return(
            {
              body: "authenticate",
              status: 401,
              headers: {"www-authenticate": %(Basic realm="Use your SUSE developer account")}
            },
            {
              body: ->(request) { request.headers["Authorization"] },
              status: 200
            },
            {
              body: ->(request) { request.headers["Authorization"] },
              status: 200
            }
          )
      end

      # here we're ignoring subject. It's intended to perform the request
      # multiple times
      it "preserves the authentication" do
        res1 = conn.get(base_url + "/auth-echo")
        expect(res1.status).to be(200)
        expected = %(Basic #{Base64.encode64("foo:bar").strip})
        expect(res1.body).to eq(expected)

        res2 = conn.get(base_url + "/auth-echo")
        expect(res1.body).to eq(res2.body)
      end
    end
  end

  describe "Unknown Challange" do
    subject(:response) { conn.get(base_url + "/auth-echo") }

    before do
      stub_request(:get, base_url + "/auth-echo")
        .to_return(
          {
            body: "authenticate",
            status: 401,
            headers: {"www-authenticate": %(TokenZ realm="Use your SUSE developer account")}
          }
        )
    end

    it "raises an error" do
      expect { response }.to raise_error(/Unknown challenge TokenZ/)
    end
  end

  describe "Signature authentication needed" do
    subject(:response) { conn.get(base_url + "/auth-echo") }

    let(:credentials) do
      {
        username: "foo",
        password: "bar",
        ssh_key: "baz"
      }
    end

    # NOTE: Here we're testing that the client does retry a request after
    #       authentication is requested. The behavior of the signer is tested
    #       separately.
    let(:signer) do
      instance_double(Faraday::Middlewares::BuildService::SshSigner, {
        generate: "%computed signature here%"
      })
    end

    before do
      class_double(Faraday::Middlewares::BuildService::SshSigner, new: signer).as_stubbed_const

      # allow(signer).to receive(:new).and_call_original
      # allow(signer).to receive(:generate).and_return('lol')
      # Fail the first request with Auth basic
      # Check the second for user/password
      stub_request(:get, base_url + "/auth-echo")
        .to_return(
          {
            body: "authenticate",
            status: 401,
            headers: {"www-authenticate": %(Signature realm="Use your SUSE developer account")}
          },
          {
            body: ->(request) { request.headers["Authorization"] },
            status: 200
          }
        )
    end

    it "performs the request" do
      # heads up: response is not a rails response, it's a Faraday::Response object.
      expect(response.status).to eq(200) # rubocop:disable RSpec/Rails/HaveHttpStatus
      expected = %(Signature %computed signature here%)
      expect(response.body).to eq(expected)
    end

    context "when follow up requests are done" do
      before do
        # heads-up: stub_request will overwrite stubs if they match perfectly
        #           see: https://github.com/bblimke/webmock
        stub_request(:get, base_url + "/auth-echo")
          .to_return(
            {
              body: "authenticate",
              status: 401,
              headers: {"www-authenticate": %(Signature realm="Use your SUSE developer account")}
            },
            {
              body: ->(request) { request.headers["Authorization"] },
              status: 200
            },
            {
              body: ->(request) { request.headers["Authorization"] },
              status: 200
            }
          )
      end

      # here we're ignoring subject. It's intended to perform the request
      # multiple times
      it "preserves the authentication" do
        res1 = conn.get(base_url + "/auth-echo")
        expect(res1.status).to be(200)
        expected = %(Signature %computed signature here%)
        expect(res1.body).to eq(expected)

        res2 = conn.get(base_url + "/auth-echo")
        expect(res1.body).to eq(res2.body)
      end
    end
  end
end
