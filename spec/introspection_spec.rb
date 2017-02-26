require_relative 'common.rb'


RSpec.describe "Seapig Server" do



	context "with 1 client connected" do

		around do |example|
			@server = Server.new()
			@client = Client.new(@server)
			example.run
			expect(@server).to be_alive if not example.exception
			@client.kill
			output = @server.kill
			puts output if example.exception
		end



		it "allows observing of object space" do
			@client.send(action: 'object-consumer-register', pattern: 'SeapigServer::Objects', "version-known": 0)
			expect(@client.messages(1.1)).to eq([{"action"=>"object-update", "id"=>"SeapigServer::Objects", "version-old"=>0, "version-new"=>[1, 0], "value"=>{"SeapigServer::Objects"=>{"id"=>"SeapigServer::Objects", "state"=>{"current"=>true}, "version_highest_known"=>0, "version_highest_inferred"=>nil, "consumers"=>[":2"], "producers"=>["SeapigInternalClient:1"]}}}])
		end


		it "shows new object when created by consumer connection" do
			@client.send(action: 'object-consumer-register', pattern: 'SeapigServer::Objects', "version-known": 0)
			expect(@client.messages(1.1)).to eq([{"action"=>"object-update", "id"=>"SeapigServer::Objects", "version-old"=>0, "version-new"=>[1, 0], "value"=>{"SeapigServer::Objects"=>{"id"=>"SeapigServer::Objects", "state"=>{"current"=>true}, "version_highest_known"=>0, "version_highest_inferred"=>nil, "consumers"=>[":2"], "producers"=>["SeapigInternalClient:1"]}}}])
			@client.send(action: 'object-producer-register', pattern: 'test-object-1')
			expect(@client.messages).to eq([])
			@client.send(action: 'object-consumer-register', pattern: 'test-object-1')
			expect(@client.messages(1.1)).to eq([{"action"=>"object-produce", "id"=>"test-object-1", "version-inferred"=>nil}, {"action"=>"object-update", "id"=>"SeapigServer::Objects", "version-old"=>[1, 0], "version-new"=>[1, 1], "patch"=>[{"op"=>"replace", "path"=>"/SeapigServer::Objects/version_highest_known", "value"=>[1, 0]}, {"op"=>"replace", "path"=>"/SeapigServer::Objects/version_highest_inferred", "value"=>[1, 1]}, {"op"=>"add", "path"=>"/test-object-1", "value"=>{"id"=>"test-object-1", "state"=>{"current"=>false, "producing"=>true}, "version_highest_known"=>0, "version_highest_inferred"=>nil, "consumers"=>[":2"], "producers"=>[":2"]}}]}])
		end


		it "shows new object when created by producer connection" do
			@client.send(action: 'object-consumer-register', pattern: 'SeapigServer::Objects', "version-known": 0)
			expect(@client.messages(1.1)).to eq([{"action"=>"object-update", "id"=>"SeapigServer::Objects", "version-old"=>0, "version-new"=>[1, 0], "value"=>{"SeapigServer::Objects"=>{"id"=>"SeapigServer::Objects", "state"=>{"current"=>true}, "version_highest_known"=>0, "version_highest_inferred"=>nil, "consumers"=>[":2"], "producers"=>["SeapigInternalClient:1"]}}}])
			@client.send(action: 'object-consumer-register', pattern: 'test-object-1')
			expect(@client.messages).to eq([])
			@client.send(action: 'object-producer-register', pattern: 'test-object-1')
			expect(@client.messages(1.1)).to eq([{"action"=>"object-produce", "id"=>"test-object-1", "version-inferred"=>nil}, {"action"=>"object-update", "id"=>"SeapigServer::Objects", "version-old"=>[1, 0], "version-new"=>[1, 1], "patch"=>[{"op"=>"replace", "path"=>"/SeapigServer::Objects/version_highest_known", "value"=>[1, 0]}, {"op"=>"replace", "path"=>"/SeapigServer::Objects/version_highest_inferred", "value"=>[1, 1]}, {"op"=>"add", "path"=>"/test-object-1", "value"=>{"id"=>"test-object-1", "state"=>{"current"=>false, "producing"=>true}, "version_highest_known"=>0, "version_highest_inferred"=>nil, "consumers"=>[":2"], "producers"=>[":2"]}}]}])
		end


		it "allows observing of connections" do
			@client.send(action: 'object-consumer-register', pattern: 'SeapigServer::Objects', "version-known": 0)
			expect(@client.messages).to eq([{"action"=>"object-update", "id"=>"SeapigServer::Objects", "version-old"=>0, "version-new"=>[1, 0], "value"=>{"SeapigServer::Objects"=>{"id"=>"SeapigServer::Objects", "state"=>{"current"=>true}, "version_highest_known"=>0, "version_highest_inferred"=>nil, "consumers"=>[":2"], "producers"=>["SeapigInternalClient:1"]}}}])
		end


	end

end
