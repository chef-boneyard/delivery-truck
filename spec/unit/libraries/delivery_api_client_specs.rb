require 'spec_helper'

describe DeliveryTruck::DeliveryApiClient do
  let(:node) do
    {
      'delivery' => { 'change' => {'enterprise' => 'Example_Enterprise'} },
      'delivery_builder' => { 'workspace' => '/var/opt/delivery/workspace' }
    }
  end

  let(:api_host) { 'delivery.example.com' }
  let(:api_url) { 'https://' + api_host }
  let(:api_port) { 443 }
  let(:api_token) { 'DECAFBAD' }

  let(:change_json) do
    JSON.generate({
      'delivery_api_url' => api_url,
      'token' => api_token,
    })
  end

  let(:expected_headers) do
    {
       'chef-delivery-token' => api_token,
       'chef-delivery-user'  => 'builder',
    }
  end

  let(:http_client) { double 'Net::HTTP' }

  before(:each) do
    allow(File)
      .to receive(:read)
      .and_return(change_json)
  end

  describe '.blocked_projects' do
    let(:blocked_project_api) { '/api/v0/e/Example_Enterprise/blocked_projects' }

    context 'when api url is http' do
      let(:api_url) { 'http://' + api_host }
      let(:api_port) { 80 }

      it 'does not set ssl settings' do
        expect(Net::HTTP).
          to receive(:new).
          with(api_host, api_port).
          and_return(http_client)
        expect(http_client).
          to receive(:get).
          with(blocked_project_api, expected_headers).
          and_return(OpenStruct.new({:code => "404"}))
        result = DeliveryTruck::DeliveryApiClient.blocked_projects(node)
        expect(result).to eql([])
      end
    end

    context 'when api url is https' do
      it 'sets use ssl to true' do
        expect(Net::HTTP).
          to receive(:new).
          with(api_host, api_port).
          and_return(http_client)
        expect(http_client).
          to receive(:use_ssl=).
          with(true)
        expect(http_client).
          to receive(:verify_mode=).
          with(OpenSSL::SSL::VERIFY_NONE)
        expect(http_client).
          to receive(:get).
          with(blocked_project_api, expected_headers).
          and_return(OpenStruct.new({:code => "404"}))
        result = DeliveryTruck::DeliveryApiClient.blocked_projects(node)
        expect(result).to eql([])
      end
    end

    context 'responses' do
      before(:each) do
        allow(Net::HTTP).
          to receive(:new).
          with(api_host, api_port).
          and_return(http_client)
        allow(http_client).
          to receive(:use_ssl=).
          with(true)
        allow(http_client).
          to receive(:verify_mode=).
          with(OpenSSL::SSL::VERIFY_NONE)
      end

      context 'when server returns an error' do
        before do
          expect(http_client).
            to receive(:get).
            with(blocked_project_api, expected_headers).
            and_return(OpenStruct.new({:code => error_code}))
        end

        context 'status 404' do
          let(:error_code) { "404" }

          it 'returns empty array' do
            result = DeliveryTruck::DeliveryApiClient.blocked_projects(node)
            expect(result).to eql([])
          end
        end

        context 'status not 404' do
          let(:error_code) { "500" }

          it 'logs and reraises' do
            # Swallow error reporting, to avoid cluttering test output
            allow(Chef::Log).
              to receive(:error)

            expect{DeliveryTruck::DeliveryApiClient.blocked_projects(node)}.
                to raise_exception(DeliveryTruck::DeliveryApiClient::BadApiResponse)
          end
        end
      end

      context 'when request succeeds' do
        let(:http_response) { double 'Net::HTTPOK' }
        let(:json_response) do
          JSON.generate({
            'blocked_projects' => ['project_name_1', 'project_name_2']
          })
        end

        before do
          expect(http_response).
            to receive(:body).
            and_return(json_response)
          allow(http_response).
            to receive(:code).
            and_return("200")
          expect(http_client).
            to receive(:get).
            with(blocked_project_api, expected_headers).
            and_return(http_response)
        end

        it 'returns deserialized list' do
          result = DeliveryTruck::DeliveryApiClient.blocked_projects(node)
          expect(result).to eql(['project_name_1', 'project_name_2'])
        end
      end
    end
  end
end
