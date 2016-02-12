# require 'spec_helper'

# describe DeliveryTruck::DeliveryApiClient do
#   let(:node) do
#     {
#       'delivery' => { 'change' => {'enterprise' => 'Example_Enterprise'} },
#       'delivery_builder' => { 'workspace' => '/var/opt/delivery/workspace' }
#     }
#   end

#   let(:api_host) { 'delivery.example.com' }
#   let(:api_url) { 'https://' + api_host }
#   let(:api_port) { 443 }
#   let(:api_token) { 'DECAFBAD' }

#   let(:change_json) do
#     JSON.generate({
#       'delivery_api_url' => api_url,
#       'token' => api_token
#     })
#   end

#   let(:expected_headers) do
#     {
#        'chef-delivery-token' => api_token,
#        'chef-delivery-user'  => 'builder'
#     }
#   end

#   let(:http_client) { double 'Net::HTTP' }

#   before(:each) do
#     allow(File).
#       to receive(:read).
#       with('/var/opt/delivery/workspace/change.json').
#       and_return(change_json)
#     allow(Net::HTTP).
#       to receive(:new).
#       with(api_host, api_port).
#       and_return(http_client)
#   end

#   describe '.blocked_projects' do
#     let(:blocked_project_api) { '/api/v0/e/Example_Enterprise/blocked_projects' }

#     context 'when server returns an error' do
#       before do
#         expect(http_client).
#           to receive(:get).
#           with(blocked_project_api, expected_headers).
#           and_raise(server_exception)
#       end

#       context 'status 404' do
#         let(:server_exception) do
#           Net::HTTPServerException.new('404: Not Found',
#             Net::HTTPNotFound.new('huh', '404', 'wat'))
#         end

#         it 'returns empty array' do
#           result = DeliveryTruck::DeliveryApiClient.blocked_projects(node)
#           expect(result).to eql([])
#         end
#       end

#       context 'status not 404' do
#         let(:server_exception) do
#           Net::HTTPServerException.new('500: server error',
#             Net::HTTPServerError.new('huh', '500', 'doom'))
#         end

#         it 'logs and reraises' do
#           # Swallow error reporting, to avoid cluttering test output
#           allow(Chef::Log).
#             to receive(:error)

#           expect{DeliveryTruck::DeliveryApiClient.blocked_projects(node)}.to raise_exception(Net::HTTPServerException)
#         end
#       end
#     end

#     context 'when request succeeds' do
#       let(:http_response) { double 'Net::HTTPOK' }
#       let(:json_response) do
#         JSON.generate({
#           'blocked_projects' => ['project_name_1', 'project_name_2']
#         })
#       end

#       before do
#         expect(http_response).
#           to receive(:body).
#           and_return(json_response)
#         expect(http_client).
#           to receive(:get).
#           with(blocked_project_api, expected_headers).
#           and_return(http_response)
#       end

#       it 'returns deserialized list' do
#         result = DeliveryTruck::DeliveryApiClient.blocked_projects(node)
#         expect(result).to eql(['project_name_1', 'project_name_2'])
#       end
#     end
#   end
# end
