require_relative 'common.rb'


#TODO: monte-carlo

RSpec.describe "Seapig Server" do


	it "starts and doesn't instantly die" do
		server = Server.new()
		sleep 0.5
		expect(server).to be_alive
		server.kill
	end


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



		it "allows client connections" do
			expect(@server.stdout).to match(/Client connected/)
		end


		it "allows clients to register as consumers" do
			@client.send(action: 'object-consumer-register', id: 'test-object', latest_known_version: 0)
			expect(@client.messages).to eq([])
			expect(@server.stdout).to match(/test-object/)
		end


		it "allows clients to unregister as consumers" do
			@client.send(action: 'object-consumer-register', id: 'test-object', latest_known_version: 0)
			expect(@client.messages).to eq([])
			@client.send(action: 'object-consumer-unregister', id: 'test-object')
			expect(@client.messages).to eq([])
		end


		it "allows clients to register as producers" do
			@client.send(action: 'object-producer-register', pattern: 'test-object')
			expect(@client.messages).to eq([])
			expect(@server.stdout).to match(/test-object/)
		end


		it "allows clients to unregister as producers" do
			@client.send(action: 'object-producer-register', pattern: 'test-object')
			expect(@client.messages).to eq([])
			@client.send(action: 'object-producer-unregister', pattern: 'test-object')
			expect(@client.messages).to eq([])
		end


		it "allows clients to register as consumer and producer for the same object (id,id) and triggers production" do
			@client.send(action: 'object-consumer-register', id: 'test-object', latest_known_version: 0)
			@client.send(action: 'object-producer-register', pattern: 'test-object')
			expect(@client.messages).to eq([{"action"=>"object-produce", "id"=>"test-object", "version"=>nil}])
		end


		it "allows clients to register as consumer and producer for the same object (id,pattern) and triggers production" do
			@client.send(action: 'object-consumer-register', id: 'test-object', latest_known_version: 0)
			@client.send(action: 'object-producer-register', pattern: 'test-*')
			expect(@client.messages).to eq([{"action"=>"object-produce", "id"=>"test-object", "version"=>nil}])
		end


		it "allows clients to register as consumer and producer for the same object (pattern,id) and triggers production" do
			@client.send(action: 'object-consumer-register', id: 'test-*', latest_known_version: 0)
			@client.send(action: 'object-producer-register', pattern: 'test-object')
			expect(@client.messages).to eq([{"action"=>"object-produce", "id"=>"test-object", "version"=>nil}])
		end


		it "allows clients to register as multiple consumers and producer for the same object ((id,wildcard),id) and triggers production" do
			@client.send(action: 'object-consumer-register', id: 'test-object', latest_known_version: 0)
			@client.send(action: 'object-consumer-register', id: 'test-*', latest_known_version: 0)
			@client.send(action: 'object-producer-register', pattern: 'test-object')
			expect(@client.messages).to eq([{"action"=>"object-produce", "id"=>"test-object", "version"=>nil}])
		end


		it "allows clients to register as consumer and multiple producers for the same object (id,(id,wildcard)) and triggers production" do
			@client.send(action: 'object-consumer-register', id: 'test-object', latest_known_version: 0)
			@client.send(action: 'object-producer-register', pattern: 'test-object')
			@client.send(action: 'object-producer-register', pattern: 'test-*')
			expect(@client.messages).to eq([{"action"=>"object-produce", "id"=>"test-object", "version"=>nil}])
		end


		it "accepts and forwards object updates by value with correct new and old versions, with old version = 0, with direct producer and direct consumer" do
			@client.send(action: 'object-consumer-register', id: 'test-object', latest_known_version: 0)
			@client.send(action: 'object-producer-register', pattern: 'test-object')
			expect(@client.messages).to eq([{"action"=>"object-produce", "id"=>"test-object", "version"=>nil}])
			@client.send(action: 'object-patch', id: 'test-object', value: {"v"=>1}, old_version: 0, new_version: 1)
			expect(@client.messages).to eq([{"action"=>"object-update", "id"=>"test-object", "old_version"=>0, "new_version"=>1, "value"=>{"v"=>1}}])
		end


		it "accepts and forwards object updates by value with correct new and old versions, with old version = 0, with new version being nested version, with direct producer and direct consumer" do
			@client.send(action: 'object-consumer-register', id: 'test-object', latest_known_version: 0)
			@client.send(action: 'object-producer-register', pattern: 'test-object')
			expect(@client.messages).to eq([{"action"=>"object-produce", "id"=>"test-object", "version"=>nil}])
			@client.send(action: 'object-patch', id: 'test-object', value: {"v"=>1}, old_version: 0, new_version: {"a"=>{"b"=>1}})
			expect(@client.messages).to eq([{"action"=>"object-update", "id"=>"test-object", "old_version"=>0, "new_version"=>{"a"=>{"b"=>1}}, "value"=>{"v"=>1}}])
		end


		it "accepts and forwards object updates by value with correct new and old versions, with old and new versions being nested versions, with direct producer and direct consumer" do
			@client.send(action: 'object-consumer-register', id: 'test-object', latest_known_version: 0)
			@client.send(action: 'object-producer-register', pattern: 'test-object')
			expect(@client.messages).to eq([{"action"=>"object-produce", "id"=>"test-object", "version"=>nil}])
			@client.send(action: 'object-patch', id: 'test-object', value: {"v"=>1}, old_version: 0, new_version: {"a"=>{"b"=>1}})
			expect(@client.messages).to eq([{"action"=>"object-update", "id"=>"test-object", "old_version"=>0, "new_version"=>{"a"=>{"b"=>1}}, "value"=>{"v"=>1}}])
			@client.send(action: 'object-patch', id: 'test-object', value: {"v"=>2}, old_version: 0, new_version: {"a"=>{"b"=>2}})
			expect(@client.messages).to eq([{"action"=>"object-update", "id"=>"test-object", "old_version"=>{"a"=>{"b"=>1}}, "new_version"=>{"a"=>{"b"=>2}}, "patch"=>[{"op"=>"replace", "path"=>"/v", "value"=>2}]}])
		end


		it "rejects and doesn't forward object updates by value with reversed new and old versions, with old and new versions being nested versions, with direct producer and direct consumer" do
			@client.send(action: 'object-consumer-register', id: 'test-object', latest_known_version: 0)
			@client.send(action: 'object-producer-register', pattern: 'test-object')
			expect(@client.messages).to eq([{"action"=>"object-produce", "id"=>"test-object", "version"=>nil}])
			@client.send(action: 'object-patch', id: 'test-object', value: {"v"=>1}, old_version: 0, new_version: {"a"=>{"b"=>2}})
			expect(@client.messages).to eq([{"action"=>"object-update", "id"=>"test-object", "old_version"=>0, "new_version"=>{"a"=>{"b"=>2}}, "value"=>{"v"=>1}}])
			@client.send(action: 'object-patch', id: 'test-object', value: {"v"=>2}, old_version: 0, new_version: {"a"=>{"b"=>1}})
			expect(@client.messages).to eq([])
		end


		it "object that lacks direct producer or consumer gets destroyed from wildcard observers pov" do
			@client.send(action: 'object-consumer-register', id: 'test-*', latest_known_version: 0)
			@client.send(action: 'object-producer-register', pattern: 'test-object')
			expect(@client.messages).to eq([{"action"=>"object-produce", "id"=>"test-object", "version"=>nil}])
			@client.send(action: 'object-producer-unregister', pattern: 'test-object')
			expect(@client.messages).to eq([{"action"=>"object-destroy", "id"=>"test-object"}])
		end


		it "accepts and forwards object updates by value with correct new and old versions, with old version = 0, with direct producer and direct consumer" do
			@client.send(action: 'object-consumer-register', id: 'test-object-1', latest_known_version: 0)
			@client.send(action: 'object-producer-register', pattern: 'test-object-1')
			expect(@client.messages).to eq([{"action"=>"object-produce", "id"=>"test-object-1", "version"=>nil}])
			@client.send(action: 'object-patch', id: 'test-object-1', value: {"v"=>1}, old_version: 0, new_version: {"test-object-2"=>0})
			expect(@client.messages).to eq([{"action"=>"object-update", "id"=>"test-object-1", "old_version"=>0, "new_version"=>{"test-object-2"=>0}, "value"=>{"v"=>1}}])
			@client.send(action: 'object-patch', id: 'test-object-2', value: {"x"=>2}, old_version: 0, new_version: 1)
			expect(@client.messages).to eq([{"action"=>"object-produce", "id"=>"test-object-1", "version"=>{"test-object-2"=>1}}])
		end


		it "accepts and does not forward object stalls with correct new and old versions, with old version = 0, with direct producer and direct consumer" do
			@client.send(action: 'object-consumer-register', id: 'test-object', latest_known_version: 0)
			@client.send(action: 'object-producer-register', pattern: 'test-object')
			expect(@client.messages).to eq([{"action"=>"object-produce", "id"=>"test-object", "version"=>nil}])
			@client.send(action: 'object-patch', id: 'test-object', value: false, old_version: 0, new_version: 1)
			expect(@client.messages).to eq([])
		end


		it "accepts and forwords object unstalls, updated by value, with correct new and old versions, with old version = 0, with direct producer and direct consumer" do
			@client.send(action: 'object-consumer-register', id: 'test-object', latest_known_version: 0)
			@client.send(action: 'object-producer-register', pattern: 'test-object')
			expect(@client.messages).to eq([{"action"=>"object-produce", "id"=>"test-object", "version"=>nil}])
			@client.send(action: 'object-patch', id: 'test-object', value: false, old_version: 0, new_version: 1)
			expect(@client.messages).to eq([])
			@client.send(action: 'object-patch', id: 'test-object', value: {"x"=>2}, old_version: 1, new_version: 2)
			expect(@client.messages).to eq([{"action"=>"object-update", "id"=>"test-object", "old_version"=>0, "new_version"=>2, "value"=>{"x"=>2}}])
			@client.send(action: 'object-patch', id: 'test-object', value: false, old_version: 2, new_version: 3)
			expect(@client.messages).to eq([])
			@client.send(action: 'object-patch', id: 'test-object', value: {"f"=>3}, old_version: 3, new_version: 4)
			expect(@client.messages).to eq([{"action"=>"object-update", "id"=>"test-object", "old_version"=>2, "new_version"=>4, "patch"=>[{"op"=>"add", "path"=>"/f", "value"=>3}, {"op"=>"remove", "path"=>"/x"}]}])
		end


		it "allows cancelation of production through sending null object, requeuing the object" do
			@client.send(action: 'object-consumer-register', id: 'test-object', latest_known_version: 0)
			@client.send(action: 'object-producer-register', pattern: 'test-object')
			expect(@client.messages).to eq([{"action"=>"object-produce", "id"=>"test-object", "version"=>nil}])
			@client.send(action: 'object-patch', id: 'test-object')
			expect(@client.messages).to eq([{"action"=>"object-produce", "id"=>"test-object", "version"=>nil}])
		end


		it "allows cancelation of production through unregistering production, requeuing the object" do
			@client.send(action: 'object-consumer-register', id: 'test-object', latest_known_version: 0)
			@client.send(action: 'object-producer-register', pattern: 'test-object')
			expect(@client.messages).to eq([{"action"=>"object-produce", "id"=>"test-object", "version"=>nil}])
			@client.send(action: 'object-producer-unregister', pattern: 'test-object')
			expect(@client.messages).to eq([])
			@client.send(action: 'object-producer-register', pattern: 'test-object')
			expect(@client.messages).to eq([{"action"=>"object-produce", "id"=>"test-object", "version"=>nil}])
		end


		it "does not recalulate object if dependency version changed to same or lower version than stored in object" do
			@client.send(action: 'object-consumer-register', id: 'test-object-1', latest_known_version: 0)
			@client.send(action: 'object-producer-register', pattern: 'test-object-1')
			expect(@client.messages).to eq([{"action"=>"object-produce", "id"=>"test-object-1", "version"=>nil}])
			@client.send(action: 'object-patch', id: 'test-object-1', value: {"v"=>1}, old_version: 0, new_version: {"test-object-2"=>2})
			expect(@client.messages).to eq([{"action"=>"object-update", "id"=>"test-object-1", "old_version"=>0, "new_version"=>{"test-object-2"=>2}, "value"=>{"v"=>1}}])
			@client.send(action: 'object-patch', id: 'test-object-2', value: {"x"=>2}, old_version: 0, new_version: 1)
			expect(@client.messages).to eq([])
			@client.send(action: 'object-patch', id: 'test-object-2', value: {"x"=>2}, old_version: 1, new_version: 2)
			expect(@client.messages).to eq([])
		end


		it "object is not deleted if something depends on it, after explicit version upload [or maybe version is not deleted, data could]" do
			@client.send(action: 'object-consumer-register', id: 'test-object-1', latest_known_version: 0)
			@client.send(action: 'object-producer-register', pattern: 'test-object-1')
			@client.send(action: 'object-producer-register', pattern: 'test-object-2')
			expect(@client.messages).to eq([{"action"=>"object-produce", "id"=>"test-object-1", "version"=>nil}])
			@client.send(action: 'object-patch', id: 'test-object-1', value: {"v"=>1}, old_version: 0, new_version: {"test-object-2"=>2})
			expect(@client.messages).to eq([{"action"=>"object-update", "id"=>"test-object-1", "old_version"=>0, "new_version"=>{"test-object-2"=>2}, "value"=>{"v"=>1}},{"action"=>"object-produce", "id"=>"test-object-2", "version"=>nil}])
			@client.send(action: 'object-patch', id: 'test-object-2', value: {"x"=>2}, old_version: 0, new_version: 1)
			expect(@client.messages).to eq([]) #[{"action"=>"object-produce", "id"=>"test-object-2"}])  # interesting
			@client.send(action: 'object-consumer-register', id: 'test-object-2', latest_known_version: 0)
			expect(@client.messages).to eq([{"action"=>"object-update", "id"=>"test-object-2", "old_version"=>0, "new_version"=>1, "value"=>{"x"=>2}}])
		end


		it "object is not deleted if something depends on it, when last consumer unregisters [or maybe version is not deleted, data could]" do
			@client.send(action: 'object-consumer-register', id: 'test-object-1', latest_known_version: 0)
			@client.send(action: 'object-consumer-register', id: 'test-object-2', latest_known_version: 0)
			@client.send(action: 'object-producer-register', pattern: 'test-object-1')
			@client.send(action: 'object-producer-register', pattern: 'test-object-2')
			expect(@client.messages).to eq([{"action"=>"object-produce", "id"=>"test-object-1", "version"=>nil}])
			@client.send(action: 'object-patch', id: 'test-object-1', value: {"v"=>1}, old_version: 0, new_version: {"test-object-2"=>2})
			expect(@client.messages).to eq([{"action"=>"object-update", "id"=>"test-object-1", "old_version"=>0, "new_version"=>{"test-object-2"=>2}, "value"=>{"v"=>1}}, {"action"=>"object-produce", "id"=>"test-object-2", "version"=>nil}])
			@client.send(action: 'object-patch', id: 'test-object-2', value: {"x"=>2}, old_version: 0, new_version: 1)
			expect(@client.messages).to eq([{"action"=>"object-update", "id"=>"test-object-2", "old_version"=>0, "new_version"=>1, "value"=>{"x"=>2}}])
			@client.send(action: 'object-consumer-unregister', id: 'test-object-2')
			expect(@client.messages).to eq([])
			@client.send(action: 'object-consumer-register', id: 'test-object-2', latest_known_version: 0)
			expect(@client.messages).to eq([{"action"=>"object-update", "id"=>"test-object-2", "old_version"=>0, "new_version"=>1, "value"=>{"x"=>2}}])
		end


		it "IMPLEMENTATION SPECIFIC: object is deleted when last listener unlistens ", xxx: true do # this is only valid for minimim-caching servers
			@client.send(action: 'object-consumer-register', id: 'test-object-1', latest_known_version: 0)
			@client.send(action: 'object-producer-register', pattern: 'test-object-1')
			expect(@client.messages).to eq([{"action"=>"object-produce", "id"=>"test-object-1", "version"=>nil}])
			@client.send(action: 'object-patch', id: 'test-object-1', value: {"v"=>1}, old_version: 0, new_version: 1)
			expect(@client.messages).to eq([{"action"=>"object-update", "id"=>"test-object-1", "old_version"=>0, "new_version"=>1, "value"=>{"v"=>1}}])
			@client.send(action: 'object-consumer-unregister', id: 'test-object-1')
			expect(@client.messages).to eq([])
			@client.send(action: 'object-consumer-register', id: 'test-object-1', latest_known_version: 0)
			expect(@client.messages).to eq([{"action"=>"object-produce", "id"=>"test-object-1", "version"=>nil}])
		end


		it "object patch is forwarded even when received from non-producer" do
			@client.send(action: 'object-consumer-register', id: 'test-object-1', latest_known_version: 0)
			expect(@client.messages).to eq([])
			@client.send(action: 'object-patch', id: 'test-object-1', value: {"v"=>1}, old_version: 0, new_version: 1)
			expect(@client.messages).to eq([{"action"=>"object-update", "id"=>"test-object-1", "old_version"=>0, "new_version"=>1, "value"=>{"v"=>1}}])
		end


		it "IMPLEMENTATION SPECIFIC: object received from non-producer is not retained" do # this is only valid for minimim-caching servers
			@client.send(action: 'object-patch', id: 'test-object-1', value: {"v"=>1}, old_version: 0, new_version: 1)
			expect(@client.messages).to eq([])
			@client.send(action: 'object-consumer-register', id: 'test-object-1', latest_known_version: 0)
			expect(@client.messages).to eq([])
		end


		it "IMPLEMENTATION SPECIFIC: object is deleted when last listener unlistens, by disconnecting" do # this is only valid for minimim-caching servers
			@client.send(action: 'object-consumer-register', id: 'test-object-1', latest_known_version: 0)
			@client.send(action: 'object-producer-register', pattern: 'test-object-1')
			expect(@client.messages).to eq([{"action"=>"object-produce", "id"=>"test-object-1", "version"=>nil}])
			@client.send(action: 'object-patch', id: 'test-object-1', value: {"v"=>1}, old_version: 0, new_version: 1)
			expect(@client.messages).to eq([{"action"=>"object-update", "id"=>"test-object-1", "old_version"=>0, "new_version"=>1, "value"=>{"v"=>1}}])
			@client.kill
			@client = Client.new(@server)
			@client.send(action: 'object-consumer-register', id: 'test-object-1', latest_known_version: 0)
			expect(@client.messages).to eq([])
		end


		it "object is deleted (from wildcard-consumers' pov) when last direct consumer unlistens, by disconnecting" do
			@client2 = Client.new(@server)
			@client2.send(action: 'object-consumer-register', id: 'test-object-*', latest_known_version: 0)
			@client.send(action: 'object-consumer-register', id: 'test-object-1')
			@client.send(action: 'object-producer-register', pattern: 'test-object-1')
			expect(@client.messages).to eq([{"action"=>"object-produce", "id"=>"test-object-1", "version"=>nil}])
			@client.send(action: 'object-consumer-unregister', id: 'test-object-1')
			expect(@client.messages).to eq([])
			@client.kill
			expect(@client2.messages).to eq([{"action"=>"object-destroy", "id"=>"test-object-1"}])
			@client2.kill
		end


		it "object is deleted (from wildcard-consumers' pov) when last direct producer unlistens, by disconnecting" do
			@client2 = Client.new(@server)
			@client2.send(action: 'object-consumer-register', id: 'test-object-*', latest_known_version: 0)
			@client.send(action: 'object-producer-register', pattern: 'test-object-1')
			expect(@client.messages).to eq([{"action"=>"object-produce", "id"=>"test-object-1", "version"=>nil}])
			@client.kill
			expect(@client2.messages).to eq([{"action"=>"object-destroy", "id"=>"test-object-1"}])
			@client2.kill
		end


		it "if client dies during production - object production gets assigned to next producer" do
			@client2 = Client.new(@server)
			@client.send(action: 'object-consumer-register', id: 'test-object-1', latest_known_version: 0)
			@client2.send(action: 'object-producer-register', pattern: 'test-object-1')
			expect(@client2.messages).to eq([{"action"=>"object-produce", "id"=>"test-object-1", "version"=>nil}])
			@client.send(action: 'object-producer-register', pattern: 'test-object-1')
			@client2.kill
			expect(@client.messages).to eq([{"action"=>"object-produce", "id"=>"test-object-1", "version"=>nil}])
		end


		it "if client unregisters as direct producer during production - object production gets assigned to next producer" do
			@client2 = Client.new(@server)
			@client.send(action: 'object-consumer-register', id: 'test-object-1', latest_known_version: 0)
			@client2.send(action: 'object-producer-register', pattern: 'test-object-1')
			expect(@client2.messages).to eq([{"action"=>"object-produce", "id"=>"test-object-1", "version"=>nil}])
			@client.send(action: 'object-producer-register', pattern: 'test-object-1')
			@client2.send(action: 'object-producer-unregister', pattern: 'test-object-1')
			expect(@client.messages).to eq([{"action"=>"object-produce", "id"=>"test-object-1", "version"=>nil}])
		end


		it "if client unregisters as wildcard producer during production - object production gets assigned to next producer" do
			@client2 = Client.new(@server)
			@client.send(action: 'object-consumer-register', id: 'test-object-1', latest_known_version: 0)
			@client2.send(action: 'object-producer-register', pattern: 'test-object-*')
			expect(@client2.messages).to eq([{"action"=>"object-produce", "id"=>"test-object-1", "version"=>nil}])
			@client.send(action: 'object-producer-register', pattern: 'test-object-1')
			@client2.send(action: 'object-producer-unregister', pattern: 'test-object-*')
			expect(@client.messages).to eq([{"action"=>"object-produce", "id"=>"test-object-1", "version"=>nil}])
		end


		it "requeues object production if producer submits patch with inaccessible old_version" do
			@client.send(action: 'object-consumer-register', id: 'test-object', latest_known_version: 0)
			@client.send(action: 'object-producer-register', pattern: 'test-object')
			expect(@client.messages).to eq([{"action"=>"object-produce", "id"=>"test-object", "version"=>nil}])
			@client.send(action: 'object-patch', id: 'test-object', patch: {"v"=>1}, old_version: 1, new_version: 2)
			expect(@client.messages).to eq([{"action"=>"object-produce", "id"=>"test-object", "version"=>nil}])
		end


		#  no idea
		#it "ignores updates with mixed dep versions, NOT re-requesting generation" do
		#	@client.send(action: 'object-consumer-register', id: 'test-object', latest_known_version: 0)
		#	@client.send(action: 'object-producer-register', pattern: 'test-object')
		#	expect(@client.messages).to eq([{"action"=>"object-produce", "id"=>"test-object"}])
		#	@client.send(action: 'object-patch', id: 'test-object', value: {"v"=>1}, old_version: 0, new_version: {'a'=>1,'b'=>2})
		#	expect(@client.messages).to eq([{"action"=>"object-update", "id"=>"test-object", "old_version"=>0, "new_version"=>{"a"=>1, "b"=>2}, "value"=>{"v"=>1}}])
		#	@client.send(action: 'object-patch', id: 'a', value: {}, old_version: 0, new_version: 2)
		#	expect(@client.messages).to eq([{"action"=>"object-produce", "id"=>"test-object"}])
		#	@client.send(action: 'object-patch', id: 'test-object', value: {"v"=>1}, old_version: 0, new_version: {'a'=>2,'b'=>1})
		#	expect(@client.messages).to eq([])
		#end
		#it "doesn't crash on mixed versions" do
		#	@client.send(action: 'object-consumer-register', id: 'test-object', latest_known_version: 0)
		#	@client.send(action: 'object-producer-register', pattern: 'test-object')
		#	expect(@client.messages).to eq([{"action"=>"object-produce", "id"=>"test-object"}])
		#	@client.send(action: 'object-patch', id: 'test-object', value: {"v"=>1}, old_version: 0, new_version: {'a'=>1,'b'=>2})
		#	expect(@client.messages).to eq([{"action"=>"object-update", "id"=>"test-object", "old_version"=>0, "new_version"=>{"a"=>1, "b"=>2}, "value"=>{"v"=>1}}])
		#	@client.send(action: 'object-patch', id: 'a', value: {}, old_version: 0, new_version: 2)
		#	expect(@client.messages).to eq([{"action"=>"object-produce", "id"=>"test-object"}])
		#	@client.send(action: 'object-patch', id: 'test-object', value: {"v"=>1}, old_version: 0, new_version: {'a'=>2,'b'=>1})
		#	expect(@client.messages).to eq([{"action"=>"object-update", "id"=>"test-object", "old_version"=>{"a"=>1, "b"=>2}, "new_version"=>{"a"=>2, "b"=>1}, "patch"=>[]}])
		#end


		# not yet
		#it "doesn't hang if fed with circular dependencies" do
		#	@client.send(action: 'object-consumer-register', id: 'test-object-1', latest_known_version: 0)
		#	@client.send(action: 'object-consumer-register', id: 'test-object-2', latest_known_version: 0)
		#	expect(@client.messages).to eq([])
		#	@client.send(action: 'object-patch', id: 'test-object-1', value: {"v"=>1}, old_version: 0, new_version: {"test-object-2"=>2})
		#	expect(@client.messages).to eq([{"action"=>"object-update", "id"=>"test-object-1", "old_version"=>0, "new_version"=>{"test-object-2"=>2}, "value"=>{"v"=>1}}])
		#	@client.send(action: 'object-patch', id: 'test-object-2', value: {"x"=>2}, old_version: 0, new_version: {"test-object-1"=>1})
		#	expect(@client.messages).to eq([{"action"=>"object-update", "id"=>"test-object-2", "old_version"=>0, "new_version"=>{"test-object-1"=>1}, "value"=>{"x"=>2}}])
		#end


		it "producer gets assigned new object after producing one" do
			@client.send(action: 'object-consumer-register', id: 'test-object-1', latest_known_version: 0)
			@client.send(action: 'object-consumer-register', id: 'test-object-2', latest_known_version: 0)
			@client.send(action: 'object-producer-register', pattern: 'test-object-1')
			@client.send(action: 'object-producer-register', pattern: 'test-object-2')
			expect(@client.messages).to eq([{"action"=>"object-produce", "id"=>"test-object-1", "version"=>nil}])
			@client.send(action: 'object-patch', id: 'test-object-1', value: {"v"=>1}, old_version: 0, new_version: {"test-object-2"=>2})
			expect(@client.messages).to eq([{"action"=>"object-update", "id"=>"test-object-1", "old_version"=>0, "new_version"=>{"test-object-2"=>2}, "value"=>{"v"=>1}}, {"action"=>"object-produce", "id"=>"test-object-2", "version"=>nil}])
		end


		it "object production is re-requested if produced object has lower version than required" do
			@client.send(action: 'object-consumer-register', id: 'test-object-1', latest_known_version: 0)
			@client.send(action: 'object-producer-register', pattern: 'test-object-1')
			expect(@client.messages).to eq([{"action"=>"object-produce", "id"=>"test-object-1", "version"=>nil}])
			@client.send(action: 'object-patch', id: 'test-object-1', value: {"v"=>1}, old_version: 0, new_version: {"test-object-2"=>10})
			expect(@client.messages).to eq([{"action"=>"object-update", "id"=>"test-object-1", "old_version"=>0, "new_version"=>{"test-object-2"=>10}, "value"=>{"v"=>1}}])
			@client.send(action: 'object-patch', id: 'test-object-2', value: {"v"=>1}, old_version: 0, new_version: 20)
			expect(@client.messages).to eq([{"action"=>"object-produce", "id"=>"test-object-1", "version"=>{"test-object-2"=>20}}])
			@client.send(action: 'object-patch', id: 'test-object-1', value: {"v"=>1}, old_version: 0, new_version: {"test-object-2"=>15})
			expect(@client.messages).to eq([{"action"=>"object-update", "id"=>"test-object-1", "old_version"=>{"test-object-2"=>10}, "new_version"=>{"test-object-2"=>15}, "patch"=>[]}, {"action"=>"object-produce", "id"=>"test-object-1", "version"=>{"test-object-2"=>20}}])
			@client.send(action: 'object-patch', id: 'test-object-1', value: {"v"=>1}, old_version: 0, new_version: {"test-object-2"=>20})
			expect(@client.messages).to eq([{"action"=>"object-update", "id"=>"test-object-1", "old_version"=>{"test-object-2"=>15}, "new_version"=>{"test-object-2"=>20}, "patch"=>[]}])
		end


		it "object production is re-requested if produced object has lower version than required, when knowledge about new dependency version arrived during production" do
			@client.send(action: 'object-consumer-register', id: 'test-object-1', latest_known_version: 0)
			@client.send(action: 'object-producer-register', pattern: 'test-object-1')
			expect(@client.messages).to eq([{"action"=>"object-produce", "id"=>"test-object-1", "version"=>nil}])
			@client.send(action: 'object-patch', id: 'test-object-1', value: {"v"=>1}, old_version: 0, new_version: {"test-object-2"=>10})
			expect(@client.messages).to eq([{"action"=>"object-update", "id"=>"test-object-1", "old_version"=>0, "new_version"=>{"test-object-2"=>10}, "value"=>{"v"=>1}}])
			@client.send(action: 'object-patch', id: 'test-object-2', value: {"v"=>1}, old_version: 0, new_version: 20)
			expect(@client.messages).to eq([{"action"=>"object-produce", "id"=>"test-object-1","version"=>{"test-object-2"=>20}}])
			@client.send(action: 'object-patch', id: 'test-object-2', value: {"v"=>1}, old_version: 0, new_version: 30)
			@client.send(action: 'object-patch', id: 'test-object-1', value: {"v"=>1}, old_version: 0, new_version: {"test-object-2"=>15})
			expect(@client.messages).to eq([{"action"=>"object-update", "id"=>"test-object-1", "old_version"=>{"test-object-2"=>10}, "new_version"=>{"test-object-2"=>15}, "patch"=>[]}, {"action"=>"object-produce", "id"=>"test-object-1", "version"=>{"test-object-2"=>30}}])
			@client.send(action: 'object-patch', id: 'test-object-1', value: {"v"=>1}, old_version: 0, new_version: {"test-object-2"=>30})
			expect(@client.messages).to eq([{"action"=>"object-update", "id"=>"test-object-1", "old_version"=>{"test-object-2"=>15}, "new_version"=>{"test-object-2"=>30}, "patch"=>[]}])
		end


		it "queued production is cancelled if needed version arrives before assignment 2" do
			@client.send(action: 'object-consumer-register', id: 'test-object-1', latest_known_version: 0)
			@client.send(action: 'object-producer-register', pattern: 'test-object-1')
			expect(@client.messages).to eq([{"action"=>"object-produce", "id"=>"test-object-1", "version"=>nil}])
			@client.send(action: 'object-patch', id: 'test-object-1', value: {"v"=>1}, old_version: 0, new_version: {"test-object-2"=>10})
			expect(@client.messages).to eq([{"action"=>"object-update", "id"=>"test-object-1", "old_version"=>0, "new_version"=>{"test-object-2"=>10}, "value"=>{"v"=>1}}])
			@client.send(action: 'object-patch', id: 'test-object-2', value: {"v"=>1}, old_version: 0, new_version: 20)
			expect(@client.messages).to eq([{"action"=>"object-produce", "id"=>"test-object-1", "version"=>{"test-object-2"=>20}}])
			@client.send(action: 'object-patch', id: 'test-object-2', value: {"v"=>1}, old_version: 0, new_version: 30)
			@client.send(action: 'object-patch', id: 'test-object-1', value: {"v"=>1}, old_version: 0, new_version: {"test-object-2"=>30})
			expect(@client.messages).to eq([{"action"=>"object-update", "id"=>"test-object-1", "old_version"=>{"test-object-2"=>10}, "new_version"=>{"test-object-2"=>30}, "patch"=>[]}])
		end


		it "queued production is cancelled if newer than needed version arrives before assignment 2" do
			@client.send(action: 'object-consumer-register', id: 'test-object-1', latest_known_version: 0)
			@client.send(action: 'object-producer-register', pattern: 'test-object-1')
			expect(@client.messages).to eq([{"action"=>"object-produce", "id"=>"test-object-1", "version"=>nil}])
			@client.send(action: 'object-patch', id: 'test-object-1', value: {"v"=>1}, old_version: 0, new_version: {"test-object-2"=>10})
			expect(@client.messages).to eq([{"action"=>"object-update", "id"=>"test-object-1", "old_version"=>0, "new_version"=>{"test-object-2"=>10}, "value"=>{"v"=>1}}])
			@client.send(action: 'object-patch', id: 'test-object-2', value: {"v"=>1}, old_version: 0, new_version: 20)
			expect(@client.messages).to eq([{"action"=>"object-produce", "id"=>"test-object-1", "version"=>{"test-object-2"=>20}}])
			@client.send(action: 'object-patch', id: 'test-object-2', value: {"v"=>1}, old_version: 0, new_version: 30)
			@client.send(action: 'object-patch', id: 'test-object-1', value: {"v"=>1}, old_version: 0, new_version: {"test-object-2"=>40})
			expect(@client.messages).to eq([{"action"=>"object-update", "id"=>"test-object-1", "old_version"=>{"test-object-2"=>10}, "new_version"=>{"test-object-2"=>40}, "patch"=>[]}])
		end


		it "object gets dequeued to free clients even when some of them already got the same object to produce, and requeued to client when it gets free" do
			@client2 = Client.new(@server)
			@client3 = Client.new(@server)
			@client.send(action: 'object-consumer-register', id: 'test-object-1', latest_known_version: 0)
			@client.send(action: 'object-producer-register', pattern: 'test-object-1')
			expect(@client.messages).to eq([{"action"=>"object-produce", "id"=>"test-object-1", "version"=>nil}])
			@client.send(action: 'object-patch', id: 'test-object-1', value: {"v"=>1}, old_version: 0, new_version: {"test-object-2"=>10})
			expect(@client.messages).to eq([{"action"=>"object-update", "id"=>"test-object-1", "old_version"=>0, "new_version"=>{"test-object-2"=>10}, "value"=>{"v"=>1}}])
			@client2.send(action: 'object-producer-register', pattern: 'test-object-1')
			@client3.send(action: 'object-producer-register', pattern: 'test-object-1')
			@client.send(action: 'object-patch', id: 'test-object-2', value: {"v"=>1}, old_version: 0, new_version: 20)
			expect(@client.messages).to eq([{"action"=>"object-produce", "id"=>"test-object-1", "version"=>{"test-object-2"=>20}}])
			@client.send(action: 'object-patch', id: 'test-object-2', value: {"v"=>1}, old_version: 0, new_version: 30)
			expect(@client2.messages).to eq([{"action"=>"object-produce", "id"=>"test-object-1", "version"=>{"test-object-2"=>30}}])
			@client.send(action: 'object-patch', id: 'test-object-2', value: {"v"=>1}, old_version: 0, new_version: 40)
			expect(@client3.messages).to eq([{"action"=>"object-produce", "id"=>"test-object-1", "version"=>{"test-object-2"=>40}}])
			@client2.send(action: 'object-patch', id: 'test-object-1', value: {"v"=>2}, old_version: 0, new_version: {"test-object-2"=>20})
			expect(@client.messages).to eq([{"action"=>"object-update", "id"=>"test-object-1", "old_version"=>{"test-object-2"=>10}, "new_version"=>{"test-object-2"=>20}, "patch"=>[{"op"=>"replace", "path"=>"/v", "value"=>2}]}])
			expect(@client2.messages).to eq([])
			@client2.kill
			@client3.kill
		end


		it "memory consumption of server doesn't grow continuously with new versions of object being uploaded", performance: true, slow: true do
			payload = '*'*1000000
			wait_time = 0.5
			@client.send(action: 'object-consumer-register', id: 'test-object-1', latest_known_version: 0)
			@client.send(action: 'object-producer-register', pattern: 'test-object-1')
			expect(@client.messages).to eq([{"action"=>"object-produce", "id"=>"test-object-1", "version"=>nil}])
			@client.send(action: 'object-patch', id: 'test-object-1', value: {"v"=>1,"p"=>payload}, old_version: 0, new_version: {"test-object-2"=>0})
			expect(@client.messages(wait_time)).to eq([{"action"=>"object-update", "id"=>"test-object-1", "old_version"=>0, "new_version"=>{"test-object-2"=>0}, "value"=>{"v"=>1, "p"=>payload}}])
			base_vmrss = nil
			10.times { |i|
				@server.stdout
				@server.stderr
				@server.signal("USR1")
				@client.send(action: 'object-patch', id: 'test-object-2', value: {"v"=>1}, old_version: 0, new_version: i+1)
				expect(@client.messages(wait_time)).to eq([{"action"=>"object-produce", "id"=>"test-object-1", "version"=>{"test-object-2"=>i+1}}])
				@client.send(action: 'object-patch', id: 'test-object-1', value: {"v"=>i,"p"=>payload+i.to_s}, old_version: {"test-object-2"=>i}, new_version: {"test-object-2"=>i+1})
				expect(@client.messages(wait_time)).to eq([{"action"=>"object-update", "id"=>"test-object-1", "old_version"=>{"test-object-2"=>i}, "new_version"=>{"test-object-2"=>i+1}, "patch"=>[{"op"=>"replace", "path"=>"/v", "value"=>i}, {"op"=>"replace", "path"=>"/p", "value"=>payload+i.to_s}]}])
				base_vmrss = @server.vmrss if i == 4
			}
			vmrss = @server.vmrss
			expect(vmrss).to be < (base_vmrss+3000)
		end


		it "having 2 producers, assigns production of a single object to only one producer" do
			@client2 = Client.new(@server)
			@client.send(action: 'object-producer-register', pattern: 'test-object-1')
			@client2.send(action: 'object-producer-register', pattern: 'test-object-1')
			expect(@client.messages).to eq([])
			expect(@client2.messages).to eq([])
			@client.send(action: 'object-consumer-register', id: 'test-object-1')
			expect(@client.messages).to eq([{"action"=>"object-produce", "id"=>"test-object-1", "version"=>nil}])
			expect(@client2.messages).to eq([])
			@client2.kill
		end


		it "remembers which version of object was already sent to client and sends proper diff" do
			@client2 = Client.new(@server)
			@client.send(action: 'object-consumer-register', id: 'test-object-1', latest_known_version: 0)
			@client2.send(action: 'object-producer-register', pattern: 'test-object-1')
			expect(@client.messages).to eq([])
			expect(@client2.messages).to eq([{"action"=>"object-produce", "id"=>"test-object-1", "version"=>nil}])
			@client2.send(action: 'object-patch', id: 'test-object-1', value: {"v"=>1}, old_version: 0, new_version: 1)
			expect(@client.messages).to eq([{"action"=>"object-update", "id"=>"test-object-1", "old_version"=>0, "new_version"=>1, "value"=>{"v"=>1}}])
			expect(@client2.messages).to eq([])
			@client2.send(action: 'object-patch', id: 'test-object-1', value: {"v"=>1,"a"=>2}, old_version: 0, new_version: 2)
			expect(@client.messages).to eq([{"action"=>"object-update", "id"=>"test-object-1", "old_version"=>1, "new_version"=>2, "patch"=>[{"op"=>"add", "path"=>"/a", "value"=>2}]}])
			expect(@client2.messages).to eq([])
			@client2.kill
		end


		it "properly drops client-known version on consumer-unregister, and sends proper diff" do
			@client2 = Client.new(@server)
			@client.send(action: 'object-consumer-register', id: 'test-object-1', latest_known_version: 0)
			@client2.send(action: 'object-producer-register', pattern: 'test-object-1')
			@client2.send(action: 'object-consumer-register', id: 'test-object-1')
			expect(@client.messages).to eq([])
			expect(@client2.messages).to eq([{"action"=>"object-produce", "id"=>"test-object-1", "version"=>nil}])
			@client2.send(action: 'object-patch', id: 'test-object-1', value: {"v"=>1}, old_version: 0, new_version: 1)
			expect(@client.messages).to eq([{"action"=>"object-update", "id"=>"test-object-1", "old_version"=>0, "new_version"=>1, "value"=>{"v"=>1}}])
			expect(@client2.messages).to eq([{"action"=>"object-update", "id"=>"test-object-1", "old_version"=>0, "new_version"=>1, "value"=>{"v"=>1}}])
			@client.send(action: 'object-consumer-unregister', id: 'test-object-1')
			@client2.send(action: 'object-patch', id: 'test-object-1', value: {"v"=>1,"a"=>2}, old_version: 0, new_version: 2)
			expect(@client.messages).to eq([])
			expect(@client2.messages).to eq([{"action"=>"object-update", "id"=>"test-object-1", "old_version"=>1, "new_version"=>2, "patch"=>[{"op"=>"add", "path"=>"/a", "value"=>2}]}])
			@client.send(action: 'object-consumer-register', id: 'test-object-1', latest_known_version: 0)
			expect(@client.messages).to eq([{"action"=>"object-update", "id"=>"test-object-1", "old_version"=>0, "new_version"=>2, "value"=>{"v"=>1,"a"=>2}}])
			@client2.kill
		end


		it "doesn't try to produce same object version on multiple clients" do
			@client.send(action: 'object-consumer-register', id: 'test-object-1', latest_known_version: 0)
			@client.send(action: 'object-producer-register', pattern: 'test-object-1')
			expect(@client.messages).to eq([{"action"=>"object-produce", "id"=>"test-object-1", "version"=>nil}])
			@client.send(action: 'object-patch', id: 'test-object-1', value: {"v"=>1}, old_version: 0, new_version: {"b"=>0})
			expect(@client.messages).to eq([{"action"=>"object-update", "id"=>"test-object-1", "old_version"=>0, "new_version"=>{"b"=>0}, "value"=>{"v"=>1}}])
			@client2 = Client.new(@server)
			@client2.send(action: 'object-producer-register', pattern: 'test-object-1')
			expect(@client2.messages).to eq([])
			@client.send(action: 'object-patch', id: 'b', value: {}, old_version: 0, new_version: 10)
			expect(@client.messages).to eq([{"action"=>"object-produce", "id"=>"test-object-1", "version"=>{"b"=>10}}])
			expect(@client2.messages).to eq([])
			@client2.send(action: 'object-patch', id: 'test-object-1', value: {"v"=>1}, old_version: 0, new_version: {"b"=>5})
			expect(@client.messages).to eq([{"action"=>"object-update", "id"=>"test-object-1", "old_version"=>{"b"=>0}, "new_version"=>{"b"=>5}, "patch"=>[]}])
			expect(@client2.messages).to eq([])
			@client2.kill
		end

		it "drops object when consumer unregisters in direct-consumer+direct-producer scenario" do
			@client2 = Client.new(@server)
			@client2.send(action: 'object-consumer-register', id: 'test-object-1', latest_known_version: 0)
			@client.send(action: 'object-producer-register', pattern: 'test-object-1')
			expect(@client.messages).to eq([{"action"=>"object-produce", "id"=>"test-object-1", "version"=>nil}])
			@client.send(action: 'object-patch', id: 'test-object-1', value: {"v"=>1}, old_version: 0, new_version: {"b"=>0})
			expect(@client2.messages).to eq([{"action"=>"object-update", "id"=>"test-object-1", "old_version"=>0, "new_version"=>{"b"=>0}, "value"=>{"v"=>1}}])
			@client2.kill
			expect(@client.messages).to eq([])
			@client3 = Client.new(@server)
			@client3.send(action: 'object-consumer-register', id: 'test-object-1', latest_known_version: 0)
			expect(@client3.messages).to eq([])
			expect(@client.messages).to eq([{"action"=>"object-produce", "id"=>"test-object-1", "version"=>nil}])
			@client3.kill
		end

		it "drops object when consumer unregisters in direct-consumer+wildcard-producer scenario" do
			@client2 = Client.new(@server)
			@client2.send(action: 'object-consumer-register', id: 'test-object-1', latest_known_version: 0)
			@client.send(action: 'object-producer-register', pattern: 'test-object-*')
			expect(@client.messages).to eq([{"action"=>"object-produce", "id"=>"test-object-1", "version"=>nil}])
			@client.send(action: 'object-patch', id: 'test-object-1', value: {"v"=>1}, old_version: 0, new_version: {"b"=>0})
			expect(@client2.messages).to eq([{"action"=>"object-update", "id"=>"test-object-1", "old_version"=>0, "new_version"=>{"b"=>0}, "value"=>{"v"=>1}}])
			@client2.kill
			expect(@client.messages).to eq([])
			@client3 = Client.new(@server)
			@client3.send(action: 'object-consumer-register', id: 'test-object-1', latest_known_version: 0)
			expect(@client3.messages).to eq([])
			expect(@client.messages).to eq([{"action"=>"object-produce", "id"=>"test-object-1", "version"=>nil}])
			@client3.kill
		end

		it "drops object when consumer unregisters in wildcard-consumer+direct-producer scenario" do
			@client2 = Client.new(@server)
			@client2.send(action: 'object-consumer-register', id: 'test-object-*', latest_known_version: 0)
			@client.send(action: 'object-producer-register', pattern: 'test-object-1')
			expect(@client.messages).to eq([{"action"=>"object-produce", "id"=>"test-object-1", "version"=>nil}])
			@client.send(action: 'object-patch', id: 'test-object-1', value: {"v"=>1}, old_version: 0, new_version: {"b"=>0})
			expect(@client2.messages).to eq([{"action"=>"object-update", "id"=>"test-object-1", "old_version"=>0, "new_version"=>{"b"=>0}, "value"=>{"v"=>1}}])
			@client2.kill
			expect(@client.messages).to eq([])
			@client3 = Client.new(@server)
			@client3.send(action: 'object-consumer-register', id: 'test-object-*', latest_known_version: 0)
			expect(@client3.messages).to eq([])
			expect(@client.messages).to eq([{"action"=>"object-produce", "id"=>"test-object-1", "version"=>nil}])
			@client3.kill
		end


		it "object is sent to new consumer if it was held even if producer-consumer coupling doesn't exist (any more)" do
			@client2 = Client.new(@server)
			@client2.send(action: 'object-consumer-register', id: 'test-object-1', latest_known_version: 0)
			@client.send(action: 'object-producer-register', pattern: 'test-object-1')
			expect(@client.messages).to eq([{"action"=>"object-produce", "id"=>"test-object-1", "version"=>nil}])
			@client.send(action: 'object-patch', id: 'test-object-1', value: {"v"=>1}, old_version: 0, new_version: {"b"=>1})
			expect(@client2.messages).to eq([{"action"=>"object-update", "id"=>"test-object-1", "old_version"=>0, "new_version"=>{"b"=>1}, "value"=>{"v"=>1}}])
			expect(@client.messages).to eq([])
			@client.send(action: 'object-patch', id: 'b', value: {"v"=>2}, old_version: 0, new_version: 1)
			expect(@client.messages).to eq([])
			expect(@client2.messages).to eq([])
			@client2.send(action: 'object-consumer-register', id: 'b', latest_known_version: 0)
			expect(@client2.messages).to eq([{"action"=>"object-update", "id"=>"b", "old_version"=>0, "new_version"=>1, "value"=>{"v"=>2}}])
		end


		it "drops object when last dependent gets despawned" do
			@client2 = Client.new(@server)
			@client2.send(action: 'object-consumer-register', id: 'test-object-1', latest_known_version: 0)
			@client.send(action: 'object-producer-register', pattern: 'test-object-1')
			expect(@client.messages).to eq([{"action"=>"object-produce", "id"=>"test-object-1", "version"=>nil}])
			@client.send(action: 'object-patch', id: 'test-object-1', value: {"v"=>1}, old_version: 0, new_version: {"b"=>1})
			expect(@client2.messages).to eq([{"action"=>"object-update", "id"=>"test-object-1", "old_version"=>0, "new_version"=>{"b"=>1}, "value"=>{"v"=>1}}])
			expect(@client.messages).to eq([])
			@client.send(action: 'object-patch', id: 'b', value: {"v"=>2}, old_version: 0, new_version: 1)
			expect(@client.messages).to eq([])
			expect(@client2.messages).to eq([])
			@client2.send(action: 'object-consumer-unregister', id: 'test-object-1', latest_known_version: 0)
			@client2.send(action: 'object-consumer-register', id: 'b', latest_known_version: 0)
			expect(@client2.messages).to eq([])
		end


		it "properly forgets producer of existing-because-depended-on object on producer-unregister" do
			@client.send(action: 'object-consumer-register', id: 'test-object-1', latest_known_version: 0)
			@client2 = Client.new(@server)
			@client2.send(action: 'object-producer-register', pattern: 'test-object-1')
			expect(@client2.messages).to eq([{"action"=>"object-produce", "id"=>"test-object-1", "version"=>nil}])
			@client2.send(action: 'object-patch', id: 'test-object-1', value: {"v"=>1}, old_version: 0, new_version: {"dependency"=>1})
			expect(@client.messages).to eq([{"action"=>"object-update", "id"=>"test-object-1", "old_version"=>0, "new_version"=>{"dependency"=>1}, "value"=>{"v"=>1}}])
			expect(@client2.messages).to eq([])
			@client2.send(action: 'object-producer-register', pattern: 'dependency')
			expect(@client2.messages).to eq([{"action"=>"object-produce", "id"=>"dependency", "version"=>nil}])
			expect(@client.messages).to eq([])
			@client2.send(action: 'object-producer-unregister', pattern: 'dependency', latest_known_version: 0)
			expect(@client2.messages).to eq([])
			@client.send(action: 'object-consumer-register', id: 'dependency', latest_known_version: 0)
			expect(@client.messages).to eq([])
			expect(@client2.messages).to eq([])
		end

		it "it orders build of known object if new producer connects that knows newer version" do
			@client.send(action: 'object-consumer-register', id: 'test-object-1', known_version: nil)
			@client.send(action: 'object-producer-register', pattern: 'test-object-1', "known-version" => nil)
			expect(@client.messages).to eq([{"action"=>"object-produce", "id"=>"test-object-1", "version"=>nil}])
			@client2 = Client.new(@server)
			@client2.send(action: 'object-producer-register', pattern: 'test-object-1', "known-version" => 1)
			expect(@client2.messages).to eq([{"action"=>"object-produce", "id"=>"test-object-1", "version"=>1}])
		end

	end

end
