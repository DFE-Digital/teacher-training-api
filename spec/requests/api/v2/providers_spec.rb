require "rails_helper"

describe 'Providers API v2', type: :request do
  describe 'GET /providers' do
    let(:user) { create(:user, organisations: [organisation]) }
    let(:organisation) { create(:organisation) }
    let(:payload) { { email: user.email } }
    let(:token) do
      JWT.encode payload,
                 Settings.authentication.secret,
                 Settings.authentication.algorithm
    end
    let(:credentials) do
      ActionController::HttpAuthentication::Token.encode_credentials(token)
    end

    let!(:provider) { create(:provider,
                             course_count: 0,
                             site_count: 0,
                             enrichments: [],
                             organisations: [organisation]) }

    subject { response }

    context 'when unauthorized' do
      before do
        get '/api/v2/providers', headers: { 'HTTP_AUTHORIZATION' => credentials }
      end

      let(:payload) { { email: 'foo@bar' } }

      it { should have_http_status(:unauthorized) }
    end

    describe 'JSON generated for a providers' do
      before do
        get '/api/v2/providers', headers: { 'HTTP_AUTHORIZATION' => credentials }
      end

      it { should have_http_status(:success) }

      it 'has a data section with the correct attributes' do
        json_response = JSON.parse(response.body)
        expect(json_response).to eq(
          "data" => [{
            "id" => provider.id.to_s,
            "type" => "providers",
            "attributes" => {
              "provider_code" => provider.provider_code,
              "provider_name" => provider.provider_name,
              "accredited_body?" => false,
              "can_add_more_sites?" => true,
              "website" => provider.url,
              "email" => provider.email,
              "telephone" => provider.telephone,
              "address1" => provider.address1,
              "address2" => provider.address2,
              "address3" => provider.address3,
              "address4" => provider.address4,
              "postcode" => provider.postcode,
              "train_with_us" => nil,
              "train_with_disability" => nil,
            },
            "relationships" => {
              "sites" => {
                "meta" => {
                  "included" => false
                }
              },
              "courses" => {
                "meta" => {
                  "count" => provider.courses.count
                }
              }
            }
          }],
          "jsonapi" => {
            "version" => "1.0"
          }
        )
      end
    end

    context 'nested within current user' do
      before do
        get "/api/v2/users/#{user.id}/providers", headers: { 'HTTP_AUTHORIZATION' => credentials }
      end

      it 'has a data section with the correct attributes' do
        json_response = JSON.parse(response.body)
        expect(json_response).to eq(
          "data" => [{
            "id" => provider.id.to_s,
            "type" => "providers",
            "attributes" => {
              "provider_code" => provider.provider_code,
              "provider_name" => provider.provider_name,
              "accredited_body?" => false,
              "can_add_more_sites?" => true,
              "website" => provider.url,
              "email" => provider.email,
              "telephone" => provider.telephone,
              "address1" => provider.address1,
              "address2" => provider.address2,
              "address3" => provider.address3,
              "address4" => provider.address4,
              "postcode" => provider.postcode,
              "train_with_us" => nil,
              "train_with_disability" => nil,
            },
            "relationships" => {
              "sites" => {
                "meta" => {
                  "included" => false
                }
              },
              "courses" => {
                "meta" => {
                  "count" => provider.courses.count
                }
              }
            }
          }],
          "jsonapi" => {
            "version" => "1.0"
          }
        )
      end
    end

    context 'nested within a different user' do
      let(:different_user) { create(:user) }
      before do
        get "/api/v2/users/#{different_user.id}/providers", headers: { 'HTTP_AUTHORIZATION' => credentials }
      end

      it 'has no providers' do
        json_response = JSON.parse(response.body)
        expect(json_response).to eq(
          "data" => [],
          "jsonapi" => {
            "version" => "1.0"
          }
        )
      end
    end

    context 'with unalphabetical ordering in the database' do
      let!(:second_alphabetical_provider) { create(:provider, provider_name: 'Zork', organisations: [organisation]) }

      before do
        provider.update(provider_name: 'Acme') # This moves it last in the order that it gets fetched by default.
        get "/api/v2/users/#{user.id}/providers", headers: { 'HTTP_AUTHORIZATION' => credentials }
      end

      let(:provider_names_in_response) {
        JSON.parse(response.body)["data"].map { |provider| provider["attributes"]["provider_name"] }
      }

      it 'returns them in alphabetical order' do
        expect(provider_names_in_response).to eq(%w(Acme Zork))
      end
    end

    context 'with provider enrichments' do
      before do
        get "/api/v2/users/#{user.id}/providers", headers: { 'HTTP_AUTHORIZATION' => credentials }
      end

      let(:organisation) { create(:organisation) }
      let(:enrichment)   { build :provider_enrichment, :published }
      let(:provider)    { create(:provider,
                                  course_count: 0,
                                  site_count: 0,
                                  enrichments: [enrichment],
                                  organisations: [organisation]) }

      it 'has a data section with the correct attributes' do
        json_response = JSON.parse(response.body)
        expect(json_response).to eq(
          "data" => [{
            "id" => provider.id.to_s,
            "type" => "providers",
            "attributes" => {
              "provider_code" => provider.provider_code,
              "provider_name" => provider.provider_name,
              "accredited_body?" => false,
              "can_add_more_sites?" => true,
              "website" => enrichment.website,
              "email" => enrichment.email,
              "telephone" => enrichment.telephone,
              "address1" => enrichment.address1,
              "address2" => enrichment.address2,
              "address3" => enrichment.address3,
              "address4" => enrichment.address4,
              "postcode" => enrichment.postcode,
              "train_with_us" => enrichment.train_with_us,
              "train_with_disability" => enrichment.train_with_disability
            },
            "relationships" => {
              "sites" => {
                "meta" => {
                  "included" => false
                }
              },
              "courses" => {
                "meta" => {
                  "count" => provider.courses.count
                }
              }
            }
          }],
          "jsonapi" => {
            "version" => "1.0"
          }
        )
      end
    end
  end

  describe 'GET /providers#show' do
    let(:user) { create(:user, organisations: [organisation]) }
    let(:organisation) { create(:organisation) }
    let(:payload) { { email: user.email } }
    let(:token) do
      JWT.encode payload,
                 Settings.authentication.secret,
                 Settings.authentication.algorithm
    end
    let(:credentials) do
      ActionController::HttpAuthentication::Token.encode_credentials(token)
    end

    let!(:provider) { create(:provider,
                             course_count: 0,
                             site_count: 1,
                             enrichments: [],
                             organisations: [organisation]) }

    subject { response }

    let(:expected_response) {
      {
        "data" => {
          "id" => provider.id.to_s,
          "type" => "providers",
          "attributes" => {
            "provider_code" => provider.provider_code,
            "provider_name" => provider.provider_name,
            "accredited_body?" => false,
            "can_add_more_sites?" => true,
            "website" => provider.url,
            "email" => provider.email,
            "telephone" => provider.telephone,
            "address1" => provider.address1,
            "address2" => provider.address2,
            "address3" => provider.address3,
            "address4" => provider.address4,
            "postcode" => provider.postcode,
            "train_with_us" => nil,
            "train_with_disability" => nil,
          },
          "relationships" => {
            "sites" => {
              "meta" => {
                "included" => false
              }
            },
            "courses" => {
              "meta" => {
                "count" => provider.courses.count
              }
            }
          }
        },
        "jsonapi" => {
          "version" => "1.0"
        }
      }
    }

    context 'including sites' do
      before do
        get "/api/v2/providers/#{provider.provider_code}",
            headers: { 'HTTP_AUTHORIZATION' => credentials },
            params: { include: "sites" }

        it { should have_http_status(:success) }

        it 'has a data section with the correct attributes' do
          json_response = JSON.parse(response.body)
          expect(json_response).to eq(
            "data" => [{
              "id" => provider.id.to_s,
              "type" => "providers",
              "attributes" => {
                "provider_code" => provider.provider_code,
                "provider_name" => provider.provider_name,
                "accredited_body?" => false,
                "can_add_more_sites?" => true,
                "website" => provider.url,
                "email" => provider.email,
                "telephone" => provider.telephone,
                "address1" => provider.address1,
                "address2" => provider.address2,
                "address3" => provider.address3,
                "address4" => provider.address4,
                "postcode" => provider.postcode,
                "train_with_us" => nil,
                "train_with_disability" => nil,
              },
              "relationships" => {
                "sites" => {
                  "data" => [
                    {
                      "type" => "sites",
                      "id" => "1"
                    }
                  ]
                },
                "courses" => {
                  "meta" => {
                    "count" => provider.courses.count
                  }
                }
              }
            }],
            "included": [
              {
                "id" => provider.site.id.to_s,
                "type" => "sites",
                "attributes" => {
                  "code" => provider.site.code,
                  "location_name" => provider.site.location_name
                }
              }
            ],
            "jsonapi" => {
              "version" => "1.0"
            }
          )
        end
      end
    end

    context "with the maximum number of sites" do
      let(:provider) { create(:provider, course_count: 0, site_count: Site::POSSIBLE_CODES.size, organisations: [organisation]) }

      before do
        get "/api/v2/providers/#{provider.provider_code}",
            headers: { 'HTTP_AUTHORIZATION' => credentials }
      end

      it 'has can_add_more_sites? set to false' do
        json_response = JSON.parse(response.body)
        expect(json_response["data"]["attributes"]["can_add_more_sites?"]).to eq(false)
      end
    end

    describe 'JSON generated for a provider' do
      before do
        get "/api/v2/providers/#{provider.provider_code}", headers: { 'HTTP_AUTHORIZATION' => credentials }
      end

      it { should have_http_status(:success) }

      it 'has a data section with the correct attributes' do
        json_response = JSON.parse(response.body)
        expect(json_response).to eq(expected_response)
      end
    end

    describe "with lowercase provider code" do
      before do
        get "/api/v2/providers/#{provider.provider_code.downcase}", headers: { 'HTTP_AUTHORIZATION' => credentials }
      end

      it { should have_http_status(:success) }

      it 'has a data section with the correct attributes' do
        json_response = JSON.parse(response.body)
        expect(json_response).to eq(expected_response)
      end
    end
  end
end
