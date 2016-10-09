require_relative 'common.rb'



RSpec.describe "Seapig Server doesn't exhibit a bug where" do


	around do |example|
		@server = Server.new()
		@client = Client.new(@server)
		example.run
		expect(@server).to be_alive if not example.exception
		@client.kill
		output = @server.kill
		puts output if example.exception
	end



	it "it crashes if patch arrives for object that has been depencency of previously deleted object" do
		@client.send(action: 'object-consumer-register', id: 'test-object-1')
		@client.send(action: 'object-producer-register', pattern: 'test-object-1')
		expect(@client.messages).to eq([{"action"=>"object-produce", "id"=>"test-object-1"}])
		@client.send(action: 'object-patch', id: 'test-object-1', value: {"v"=>1}, old_version: 0, new_version: { "test-object-2"=>1 })
		expect(@client.messages).to eq([{"action"=>"object-update", "id"=>"test-object-1", "old_version"=>0, "new_version"=>{"test-object-2"=>1}, "value"=>{"v"=>1}}])
		@client.send(action: 'object-consumer-register', id: 'test-object-2')
		@client.send(action: 'object-producer-register', pattern: 'test-object-2')
		expect(@client.messages).to eq([{"action"=>"object-produce", "id"=>"test-object-2"}])
		@client.send(action: 'object-patch', id: 'test-object-2', value: {"v"=>2}, old_version: 0, new_version: 1)
		expect(@client.messages).to eq([{"action"=>"object-update", "id"=>"test-object-2", "old_version"=>0, "new_version"=>1, "value"=>{"v"=>2}}])
		@client.send(action: 'object-consumer-unregister', id: 'test-object-1')
		@client.send(action: 'object-patch', id: 'test-object-2', value: {"v"=>3}, old_version: 1, new_version: 2)
		expect(@client.messages).to eq([{"action"=>"object-update", "id"=>"test-object-2", "old_version"=>1, "new_version"=>2, "patch"=>[{"op"=>"replace", "path"=>"/v", "value"=>3}]}])
	end


	it "having dependency change trigger production of 3 objects (with wildcard producer!), doesn't dequeue third object after second one gets produced" do
		@client.send(action: 'object-producer-register', pattern: 'test-object-*')

		@client.send(action: 'object-consumer-register', id: 'test-object-1')
		expect(@client.messages).to eq([{"action"=>"object-produce", "id"=>"test-object-1"}])
		@client.send(action: 'object-patch', id: 'test-object-1', value: {"v"=>1}, old_version: 0, new_version: { "test-dependency-1"=>1 })
		expect(@client.messages).to eq([{"action"=>"object-update", "id"=>"test-object-1", "old_version"=>0, "new_version"=>{"test-dependency-1"=>1}, "value"=>{"v"=>1}}])

		@client.send(action: 'object-consumer-register', id: 'test-object-2')
		expect(@client.messages).to eq([{"action"=>"object-produce", "id"=>"test-object-2"}])
		@client.send(action: 'object-patch', id: 'test-object-2', value: {"v"=>1}, old_version: 0, new_version: { "test-dependency-1"=>1 })
		expect(@client.messages).to eq([{"action"=>"object-update", "id"=>"test-object-2", "old_version"=>0, "new_version"=>{"test-dependency-1"=>1}, "value"=>{"v"=>1}}])

		@client.send(action: 'object-consumer-register', id: 'test-object-3')
		expect(@client.messages).to eq([{"action"=>"object-produce", "id"=>"test-object-3"}])
		@client.send(action: 'object-patch', id: 'test-object-3', value: {"v"=>1}, old_version: 0, new_version: { "test-dependency-1"=>1 })
		expect(@client.messages).to eq([{"action"=>"object-update", "id"=>"test-object-3", "old_version"=>0, "new_version"=>{"test-dependency-1"=>1}, "value"=>{"v"=>1}}])

		expect(@client.messages).to eq([])
		@client.send(action: 'object-patch', id: 'test-dependency-1', value: {"v"=>2}, old_version: 0, new_version: 2)
		expect(@client.messages).to eq([{"action"=>"object-produce", "id"=>"test-object-1"}])
		@client.send(action: 'object-patch', id: 'test-object-1', value: {"v"=>2}, old_version: 0, new_version: { "test-dependency-1"=>2 })
		expect(@client.messages).to eq([{"action"=>"object-update", "id"=>"test-object-1", "old_version"=>{"test-dependency-1"=>1}, "new_version"=>{"test-dependency-1"=>2}, "patch"=>[{"op"=>"replace", "path"=>"/v", "value"=>2}]}, {"action"=>"object-produce", "id"=>"test-object-2"}])
		@client.send(action: 'object-patch', id: 'test-object-2', value: {"v"=>2}, old_version: 0, new_version: { "test-dependency-1"=>2 })
		expect(@client.messages).to eq([{"action"=>"object-update", "id"=>"test-object-2", "old_version"=>{"test-dependency-1"=>1}, "new_version"=>{"test-dependency-1"=>2}, "patch"=>[{"op"=>"replace", "path"=>"/v", "value"=>2}]}, {"action"=>"object-produce", "id"=>"test-object-3"}])
	end


	it "it crashes when wildcard producer of existing object unregisters" do
		@client.send(action: 'object-consumer-register', id: 'test-object-1')
		@client.send(action: 'object-producer-register', pattern: 'test-object-*')

		expect(@client.messages).to eq([{"action"=>"object-produce", "id"=>"test-object-1"}])
		@client.send(action: 'object-patch', id: 'test-object-1', value: {"v"=>1}, old_version: 0, new_version: 1)
		expect(@client.messages).to eq([{"action"=>"object-update", "id"=>"test-object-1", "old_version"=>0, "new_version"=>1, "value"=>{"v"=>1}}])

		@client.send(action: 'object-producer-unregister', pattern: 'test-object-*')
		expect(@client.messages).to eq([])
	end


	it "it crashes when wildcard consumer of existing object unregisters" do
		@client.send(action: 'object-consumer-register', id: 'test-object-*')
		@client.send(action: 'object-producer-register', pattern: 'test-object-1')

		expect(@client.messages).to eq([{"action"=>"object-produce", "id"=>"test-object-1"}])
		@client.send(action: 'object-patch', id: 'test-object-1', value: {"v"=>1}, old_version: 0, new_version: 1)
		expect(@client.messages).to eq([{"action"=>"object-update", "id"=>"test-object-1", "old_version"=>0, "new_version"=>1, "value"=>{"v"=>1}}])

		@client.send(action: 'object-consumer-unregister', id: 'test-object-*')
		expect(@client.messages).to eq([])
	end


	it "it crashes after receiving patch update to object it's not keeping" do
		@client.send(action: 'object-consumer-register', id: 'test-object-1')
		@client.send(action: 'object-patch', id: 'test-object-1', patch: {"op"=>"replace", "path"=>"/v", "value"=>2}, old_version: {"test-object-2"=>2}, new_version: {"test-object-2"=>3})
		expect(@client.messages).to eq([])
		@client.send(action: 'object-patch', id: 'test-object-1', patch: {"op"=>"replace", "path"=>"/v", "value"=>2}, old_version: {"test-object-2"=>3}, new_version: {"test-object-2"=>4})
		expect(@client.messages).to eq([])
	end


	it "it crashes after trying to dequeue to single producer two objects at a time" do
		@client.send(action: 'object-consumer-register', id: 'test-object-1')
		@client.send(action: 'object-consumer-register', id: 'test-object-2')
		@client.send(action: 'object-consumer-register', id: 'test-object-3')
		@client.send(action: 'object-producer-register', pattern: 'test-object-1')
		expect(@client.messages).to eq([{"action"=>"object-produce", "id"=>"test-object-1"}])
		@client.send(action: 'object-patch', id: 'test-object-1', value: {"v"=>1}, old_version: 0, new_version: {"test-object-2"=>0})
		expect(@client.messages).to eq([{"action"=>"object-update", "id"=>"test-object-1", "old_version"=>0, "new_version"=>{"test-object-2"=>0}, "value"=>{"v"=>1}}])
		@client.send(action: 'object-producer-register', pattern: 'test-object-2')
		@client.send(action: 'object-producer-register', pattern: 'test-object-3')
		expect(@client.messages).to eq([{"action"=>"object-produce", "id"=>"test-object-2"}])
		@client.send(action: 'object-patch', id: 'test-object-2', value: {"v"=>2}, old_version: 0, new_version: 1)
		expect(@client.messages).to eq([{"action"=>"object-update", "id"=>"test-object-2", "old_version"=>0, "new_version"=>1, "value"=>{"v"=>2}}, {"action"=>"object-produce", "id"=>"test-object-1"}])
		@client.send(action: 'object-patch', id: 'test-object-1', value: {"v"=>1}, old_version: 0, new_version: {"test-object-2"=>1})
		expect(@client.messages).to eq([{"action"=>"object-update", "id"=>"test-object-1", "old_version"=>{"test-object-2"=>0}, "new_version"=>{"test-object-2"=>1}, "patch"=>[]}, {"action"=>"object-produce", "id"=>"test-object-3"}])
	end


	it "it crashes when getting slightly old object" do
		@client.send(action: 'object-consumer-register', id: 'test-object-1')
		@client.send(action: 'object-producer-register', pattern: 'test-object-1')
		expect(@client.messages).to eq([{"action"=>"object-produce", "id"=>"test-object-1"}])
		@client.send(action: 'object-patch', id: 'test-object-1', value: {"v"=>1}, old_version: 0, new_version: {"test-object-2"=>1,"test-object-3"=>1})
		expect(@client.messages).to eq([{"action"=>"object-update", "id"=>"test-object-1", "old_version"=>0, "new_version"=>{"test-object-2"=>1, "test-object-3"=>1}, "value"=>{"v"=>1}}])
		@client.send(action: 'object-patch', id: 'test-object-2', value: {"v"=>1}, old_version: 0, new_version: 2)
		expect(@client.messages).to eq([{"action"=>"object-produce", "id"=>"test-object-1"}])
		@client.send(action: 'object-patch', id: 'test-object-3', value: {"v"=>1}, old_version: 0, new_version: 10)
		@client.send(action: 'object-patch', id: 'test-object-1', value: {"v"=>1}, old_version: 0, new_version: {"test-object-2"=>5,"test-object-3"=>5})
		expect(@client.messages).to eq([{"action"=>"object-update", "id"=>"test-object-1", "old_version"=>{"test-object-2"=>1, "test-object-3"=>1}, "new_version"=>{"test-object-2"=>5, "test-object-3"=>5}, "patch"=>[]}, {"action"=>"object-produce", "id"=>"test-object-1"}])
	end


	it "it doesn't request production when old object arrives" do
		@client.send(action: 'object-consumer-register', id: 'test-object-1')
		@client.send(action: 'object-consumer-register', id: 'test-object-3')
		@client.send(action: 'object-producer-register', pattern: 'test-object-1')
		@client.send(action: 'object-patch', id: 'test-object-3', value: {"v"=>1}, old_version: 0, new_version: {"test-object-2"=>10})
		@client.send(action: 'object-patch', id: 'test-object-2', value: {"v"=>1}, old_version: 0, new_version: 10)
		expect(@client.messages).to eq([{"action"=>"object-produce", "id"=>"test-object-1"}, {"action"=>"object-update", "id"=>"test-object-3", "old_version"=>0, "new_version"=>{"test-object-2"=>10}, "value"=>{"v"=>1}}])
		@client.send(action: 'object-patch', id: 'test-object-1', value: {"v"=>1}, old_version: 0, new_version: {"test-object-2"=>5})
		expect(@client.messages).to eq([{"action"=>"object-update", "id"=>"test-object-1", "old_version"=>0, "new_version"=>{"test-object-2"=>5}, "value"=>{"v"=>1}}, {"action"=>"object-produce", "id"=>"test-object-1"}])
	end


	it "it doesn't drop objects that were dependencies of something that no longer exists" do
		@client.send(action: 'object-consumer-register', id: 'test-object-1')
		@client.send(action: 'object-patch', id: 'test-object-1', value: {"v"=>1}, old_version: 0, new_version: {"test-object-2"=>10})
		@client.send(action: 'object-patch', id: 'test-object-2', value: {"v"=>1}, old_version: 0, new_version: 10)
		expect(@client.messages).to eq([{"action"=>"object-update", "id"=>"test-object-1", "old_version"=>0, "new_version"=>{"test-object-2"=>10}, "value"=>{"v"=>1}}])
		@client.send(action: 'object-consumer-unregister', id: 'test-object-1')
		@client.send(action: 'object-consumer-register', id: 'test-object-2')
		expect(@client.messages).to eq([])
	end


	it "doesn't produce dependency when its producer appears" do
		@client.send(action: 'object-consumer-register', id: 'test-object-1', latest_known_version: 0)
		@client.send(action: 'object-patch', id: 'test-object-1', value: {"v"=>1}, old_version: 0, new_version: {"test-object-2"=>10})
		expect(@client.messages).to eq([{"action"=>"object-update", "id"=>"test-object-1", "old_version"=>0, "new_version"=>{"test-object-2"=>10}, "value"=>{"v"=>1}}])
		@client.send(action: 'object-producer-register', pattern: 'test-object-2')
		expect(@client.messages).to eq([{"action"=>"object-produce", "id"=>"test-object-2"}])
	end


	it "it gets into production loop when key vanishes form version" do
		@client.send(action: 'object-producer-register', pattern: 'test-object-1')
		@client.send(action: 'object-consumer-register', id: 'test-object-1')
		expect(@client.messages).to eq([{"action"=>"object-produce", "id"=>"test-object-1"}])
		@client.send(action: 'object-patch', id: 'test-object-1', value: {"v"=>1}, old_version: 0, new_version: {"dependency-a"=>10, "dependency-b"=>10})
		expect(@client.messages).to eq([{"action"=>"object-update", "id"=>"test-object-1", "old_version"=>0, "new_version"=>{"dependency-a"=>10, "dependency-b"=>10}, "value"=>{"v"=>1}}])
		@client.send(action: 'object-patch', id: 'dependency-b', value: {"v"=>1}, old_version: 0, new_version: 11)
		expect(@client.messages).to eq([{"action"=>"object-produce", "id"=>"test-object-1"}])
		@client.send(action: 'object-patch', id: 'test-object-1', value: {"v"=>2}, old_version: 0, new_version: {"dependency-a"=>10})
		expect(@client.messages).to eq([{"action"=>"object-update", "id"=>"test-object-1", "old_version"=>{"dependency-a"=>10, "dependency-b"=>10}, "new_version"=>{"dependency-a"=>10}, "patch"=>[{"op"=>"replace", "path"=>"/v", "value"=>2}]}])
	end

	it "it crashes when upgrading version from integer to hash" do
		@client.send(action: 'object-producer-register', pattern: 'test-object-1')
		@client.send(action: 'object-consumer-register', id: 'test-object-1')
		expect(@client.messages).to eq([{"action"=>"object-produce", "id"=>"test-object-1"}])
		@client.send(action: 'object-patch', id: 'test-object-1', value: {"v"=>1}, old_version: 0, new_version: 1)
		expect(@client.messages).to eq([{"action"=>"object-update", "id"=>"test-object-1", "old_version"=>0, "new_version"=>1, "value"=>{"v"=>1}}])
		@client.send(action: 'object-patch', id: 'test-object-1', value: {"v"=>1}, old_version: 1, new_version: {"dependency-a"=>10, "dependency-b"=>10})
		expect(@client.messages).to eq([{"action"=>"object-update", "id"=>"test-object-1", "old_version"=>1, "new_version"=>{"dependency-a"=>10, "dependency-b"=>10}, "patch"=>[]}])
	end

end
