require_relative 'common.rb'



RSpec.describe "Seapig Server doesn't exhibit a bug where it: " do


	around do |example|
		@server = Server.new()
		@client = Client.new(@server)
		example.run
		expect(@server).to be_alive if not example.exception
		@client.kill
		output = @server.kill
		puts output if example.exception
	end



	it "crashes if patch arrives for object that has been depencency of previously deleted object" do
		@client.send(action: 'object-consumer-register', pattern: 'test-object-1')
		@client.send(action: 'object-producer-register', pattern: 'test-object-1')
		expect(@client.messages).to eq([{"action"=>"object-produce", "id"=>"test-object-1", "version-inferred"=>nil}])
		@client.send(action: 'object-patch', id: 'test-object-1', value: {"v"=>1}, "version-old": 0, "version-new": { "test-object-2"=>1 })
		expect(@client.messages).to eq([{"action"=>"object-update", "id"=>"test-object-1", "version-old"=>0, "version-new"=>{"test-object-2"=>1}, "value"=>{"v"=>1}}])
		@client.send(action: 'object-consumer-register', pattern: 'test-object-2')
		@client.send(action: 'object-producer-register', pattern: 'test-object-2')
		expect(@client.messages).to eq([{"action"=>"object-produce", "id"=>"test-object-2", "version-inferred"=>nil}])
		@client.send(action: 'object-patch', id: 'test-object-2', value: {"v"=>2}, "version-old": 0, "version-new": 1)
		expect(@client.messages).to eq([{"action"=>"object-update", "id"=>"test-object-2", "version-old"=>0, "version-new"=>1, "value"=>{"v"=>2}}])
		@client.send(action: 'object-consumer-unregister', pattern: 'test-object-1')
		expect(@client.messages).to eq([{"action"=>"object-destroy", "id"=>"test-object-1"}])
		@client.send(action: 'object-patch', id: 'test-object-2', value: {"v"=>3}, "version-old": 1, "version-new": 2)
		expect(@client.messages).to eq([{"action"=>"object-update", "id"=>"test-object-2", "version-old"=>1, "version-new"=>2, "patch"=>[{"op"=>"replace", "path"=>"/v", "value"=>3}]}])
	end


	it "having dependency change trigger production of 3 objects (with wildcard producer!), doesn't dequeue third object after second one gets produced" do
		@client.send(action: 'object-producer-register', pattern: 'test-object-*')

		@client.send(action: 'object-consumer-register', pattern: 'test-object-1')
		expect(@client.messages).to eq([{"action"=>"object-produce", "id"=>"test-object-1", "version-inferred"=>nil}])
		@client.send(action: 'object-patch', id: 'test-object-1', value: {"v"=>1}, "version-old": 0, "version-new": { "test-dependency-1"=>1 })
		expect(@client.messages).to eq([{"action"=>"object-update", "id"=>"test-object-1", "version-old"=>0, "version-new"=>{"test-dependency-1"=>1}, "value"=>{"v"=>1}}])

		@client.send(action: 'object-consumer-register', pattern: 'test-object-2')
		expect(@client.messages).to eq([{"action"=>"object-produce", "id"=>"test-object-2", "version-inferred"=>nil}])
		@client.send(action: 'object-patch', id: 'test-object-2', value: {"v"=>1}, "version-old": 0, "version-new": { "test-dependency-1"=>1 })
		expect(@client.messages).to eq([{"action"=>"object-update", "id"=>"test-object-2", "version-old"=>0, "version-new"=>{"test-dependency-1"=>1}, "value"=>{"v"=>1}}])

		@client.send(action: 'object-consumer-register', pattern: 'test-object-3')
		expect(@client.messages).to eq([{"action"=>"object-produce", "id"=>"test-object-3", "version-inferred"=>nil}])
		@client.send(action: 'object-patch', id: 'test-object-3', value: {"v"=>1}, "version-old": 0, "version-new": { "test-dependency-1"=>1 })
		expect(@client.messages).to eq([{"action"=>"object-update", "id"=>"test-object-3", "version-old"=>0, "version-new"=>{"test-dependency-1"=>1}, "value"=>{"v"=>1}}])

		expect(@client.messages).to eq([])
		@client.send(action: 'object-patch', id: 'test-dependency-1', value: {"v"=>2}, "version-old": 0, "version-new": 2)
		expect(@client.messages).to eq([{"action"=>"object-produce", "id"=>"test-object-1", "version-inferred"=>{"test-dependency-1"=>2}}])
		@client.send(action: 'object-patch', id: 'test-object-1', value: {"v"=>2}, "version-old": 0, "version-new": { "test-dependency-1"=>2 })
		expect(@client.messages).to eq([{"action"=>"object-update", "id"=>"test-object-1", "version-old"=>{"test-dependency-1"=>1}, "version-new"=>{"test-dependency-1"=>2}, "patch"=>[{"op"=>"replace", "path"=>"/v", "value"=>2}]}, {"action"=>"object-produce", "id"=>"test-object-2", "version-inferred"=>{"test-dependency-1"=>2}}])
		@client.send(action: 'object-patch', id: 'test-object-2', value: {"v"=>2}, "version-old": 0, "version-new": { "test-dependency-1"=>2 })
		expect(@client.messages).to eq([{"action"=>"object-update", "id"=>"test-object-2", "version-old"=>{"test-dependency-1"=>1}, "version-new"=>{"test-dependency-1"=>2}, "patch"=>[{"op"=>"replace", "path"=>"/v", "value"=>2}]}, {"action"=>"object-produce", "id"=>"test-object-3", "version-inferred"=>{"test-dependency-1"=>2}}])
	end


	it "crashes when wildcard producer of existing object unregisters" do
		@client.send(action: 'object-consumer-register', pattern: 'test-object-1')
		@client.send(action: 'object-producer-register', pattern: 'test-object-*')

		expect(@client.messages).to eq([{"action"=>"object-produce", "id"=>"test-object-1", "version-inferred"=>nil}])
		@client.send(action: 'object-patch', id: 'test-object-1', value: {"v"=>1}, "version-old": 0, "version-new": 1)
		expect(@client.messages).to eq([{"action"=>"object-update", "id"=>"test-object-1", "version-old"=>0, "version-new"=>1, "value"=>{"v"=>1}}])

		@client.send(action: 'object-producer-unregister', pattern: 'test-object-*')
		expect(@client.messages).to eq([])
	end


	it "crashes when wildcard consumer of existing object unregisters" do
		@client.send(action: 'object-consumer-register', pattern: 'test-object-*')
		@client.send(action: 'object-producer-register', pattern: 'test-object-1')

		expect(@client.messages).to eq([{"action"=>"object-produce", "id"=>"test-object-1", "version-inferred"=>nil}])
		@client.send(action: 'object-patch', id: 'test-object-1', value: {"v"=>1}, "version-old": 0, "version-new": 1)
		expect(@client.messages).to eq([{"action"=>"object-update", "id"=>"test-object-1", "version-old"=>0, "version-new"=>1, "value"=>{"v"=>1}}])

		@client.send(action: 'object-consumer-unregister', pattern: 'test-object-*')
		expect(@client.messages).to eq([{"action"=>"object-destroy", "id"=>"test-object-1"}])
	end


	it "crashes after receiving patch update to object it's not keeping" do
		@client.send(action: 'object-consumer-register', pattern: 'test-object-1')
		@client.send(action: 'object-patch', id: 'test-object-1', patch: {"op"=>"replace", "path"=>"/v", "value"=>2}, "version-old": {"test-object-2"=>2}, "version-new": {"test-object-2"=>3})
		expect(@client.messages).to eq([])
		@client.send(action: 'object-patch', id: 'test-object-1', patch: {"op"=>"replace", "path"=>"/v", "value"=>2}, "version-old": {"test-object-2"=>3}, "version-new": {"test-object-2"=>4})
		expect(@client.messages).to eq([])
	end


	it "crashes after trying to dequeue to single producer two objects at a time" do
		@client.send(action: 'object-consumer-register', pattern: 'test-object-1')
		@client.send(action: 'object-consumer-register', pattern: 'test-object-2')
		@client.send(action: 'object-consumer-register', pattern: 'test-object-3')
		@client.send(action: 'object-producer-register', pattern: 'test-object-1')
		expect(@client.messages).to eq([{"action"=>"object-produce", "id"=>"test-object-1", "version-inferred"=>nil}])
		@client.send(action: 'object-patch', id: 'test-object-1', value: {"v"=>1}, "version-old": 0, "version-new": {"test-object-2"=>0})
		expect(@client.messages).to eq([{"action"=>"object-update", "id"=>"test-object-1", "version-old"=>0, "version-new"=>{"test-object-2"=>0}, "value"=>{"v"=>1}}])
		@client.send(action: 'object-producer-register', pattern: 'test-object-2')
		@client.send(action: 'object-producer-register', pattern: 'test-object-3')
		expect(@client.messages).to eq([{"action"=>"object-produce", "id"=>"test-object-2", "version-inferred"=>nil}])
		@client.send(action: 'object-patch', id: 'test-object-2', value: {"v"=>2}, "version-old": 0, "version-new": 1)
		expect(@client.messages).to eq([{"action"=>"object-update", "id"=>"test-object-2", "version-old"=>0, "version-new"=>1, "value"=>{"v"=>2}}, {"action"=>"object-produce", "id"=>"test-object-1", "version-inferred"=>{"test-object-2"=>1}}])
		@client.send(action: 'object-patch', id: 'test-object-1', value: {"v"=>1}, "version-old": 0, "version-new": {"test-object-2"=>1})
		expect(@client.messages).to eq([{"action"=>"object-update", "id"=>"test-object-1", "version-old"=>{"test-object-2"=>0}, "version-new"=>{"test-object-2"=>1}, "patch"=>[]}, {"action"=>"object-produce", "id"=>"test-object-3", "version-inferred"=>nil}])
	end


	it "crashes when getting slightly old object" do
		@client.send(action: 'object-consumer-register', pattern: 'test-object-1')
		@client.send(action: 'object-producer-register', pattern: 'test-object-1')
		expect(@client.messages).to eq([{"action"=>"object-produce", "id"=>"test-object-1", "version-inferred"=>nil}])
		@client.send(action: 'object-patch', id: 'test-object-1', value: {"v"=>1}, "version-old": 0, "version-new": {"test-object-2"=>1,"test-object-3"=>1})
		expect(@client.messages).to eq([{"action"=>"object-update", "id"=>"test-object-1", "version-old"=>0, "version-new"=>{"test-object-2"=>1, "test-object-3"=>1}, "value"=>{"v"=>1}}])
		@client.send(action: 'object-patch', id: 'test-object-3', value: {"v"=>1}, "version-old": 0, "version-new": 1)
		@client.send(action: 'object-patch', id: 'test-object-2', value: {"v"=>1}, "version-old": 0, "version-new": 2)
		expect(@client.messages).to eq([{"action"=>"object-produce", "id"=>"test-object-1", "version-inferred"=>{"test-object-2"=>2, "test-object-3"=>1}}])
		@client.send(action: 'object-patch', id: 'test-object-3', value: {"v"=>1}, "version-old": 0, "version-new": 10)
		@client.send(action: 'object-patch', id: 'test-object-1', value: {"v"=>1}, "version-old": 0, "version-new": {"test-object-2"=>5,"test-object-3"=>5})
		expect(@client.messages).to eq([{"action"=>"object-update", "id"=>"test-object-1", "version-old"=>{"test-object-2"=>1, "test-object-3"=>1}, "version-new"=>{"test-object-2"=>5, "test-object-3"=>5}, "patch"=>[]}, {"action"=>"object-produce", "id"=>"test-object-1", "version-inferred"=>{"test-object-2"=>5, "test-object-3"=>10}}])
#		expect(@client.messages).to eq([{"action"=>"object-update", "id"=>"test-object-1", "version-old"=>{"test-object-2"=>1, "test-object-3"=>1}, "version-new"=>{"test-object-2"=>5, "test-object-3"=>5}, "patch"=>[]}])
	end


	it "doesn't request production when old object arrives" do
		@client.send(action: 'object-consumer-register', pattern: 'test-object-1')
		@client.send(action: 'object-consumer-register', pattern: 'test-object-3')
		@client.send(action: 'object-producer-register', pattern: 'test-object-1')
		@client.send(action: 'object-patch', id: 'test-object-3', value: {"v"=>1}, "version-old": 0, "version-new": {"test-object-2"=>10})
		@client.send(action: 'object-patch', id: 'test-object-2', value: {"v"=>1}, "version-old": 0, "version-new": 10)
		expect(@client.messages).to eq([{"action"=>"object-produce", "id"=>"test-object-1", "version-inferred"=>nil}, {"action"=>"object-update", "id"=>"test-object-3", "version-old"=>0, "version-new"=>{"test-object-2"=>10}, "value"=>{"v"=>1}}])
		@client.send(action: 'object-patch', id: 'test-object-1', value: {"v"=>1}, "version-old": 0, "version-new": {"test-object-2"=>5})
		expect(@client.messages).to eq([{"action"=>"object-update", "id"=>"test-object-1", "version-old"=>0, "version-new"=>{"test-object-2"=>5}, "value"=>{"v"=>1}}, {"action"=>"object-produce", "id"=>"test-object-1", "version-inferred"=>{"test-object-2"=>10}}])
	end


	it "doesn't drop objects that were dependencies of something that no longer exists" do
		@client.send(action: 'object-consumer-register', pattern: 'test-object-1')
		@client.send(action: 'object-patch', id: 'test-object-1', value: {"v"=>1}, "version-old": 0, "version-new": {"test-object-2"=>10})
		@client.send(action: 'object-patch', id: 'test-object-2', value: {"v"=>1}, "version-old": 0, "version-new": 10)
		expect(@client.messages).to eq([{"action"=>"object-update", "id"=>"test-object-1", "version-old"=>0, "version-new"=>{"test-object-2"=>10}, "value"=>{"v"=>1}}])
		@client.send(action: 'object-consumer-unregister', pattern: 'test-object-1')
		@client.send(action: 'object-consumer-register', pattern: 'test-object-2')
		expect(@client.messages).to eq([])
	end


	it "doesn't produce dependency when its producer appears" do
		@client.send(action: 'object-consumer-register', pattern: 'test-object-1', latest_known_version: 0)
		@client.send(action: 'object-patch', id: 'test-object-1', value: {"v"=>1}, "version-old": 0, "version-new": {"test-object-2"=>10})
		expect(@client.messages).to eq([{"action"=>"object-update", "id"=>"test-object-1", "version-old"=>0, "version-new"=>{"test-object-2"=>10}, "value"=>{"v"=>1}}])
		@client.send(action: 'object-producer-register', pattern: 'test-object-2')
		expect(@client.messages).to eq([{"action"=>"object-produce", "id"=>"test-object-2", "version-inferred"=>nil}])
	end


	it "gets into production loop when key vanishes form version" do
		@client.send(action: 'object-producer-register', pattern: 'test-object-1')
		@client.send(action: 'object-consumer-register', pattern: 'test-object-1')
		expect(@client.messages).to eq([{"action"=>"object-produce", "id"=>"test-object-1", "version-inferred"=>nil}])
		@client.send(action: 'object-patch', id: 'test-object-1', value: {"v"=>1}, "version-old": 0, "version-new": {"dependency-a"=>10, "dependency-b"=>10})
		expect(@client.messages).to eq([{"action"=>"object-update", "id"=>"test-object-1", "version-old"=>0, "version-new"=>{"dependency-a"=>10, "dependency-b"=>10}, "value"=>{"v"=>1}}])
		@client.send(action: 'object-patch', id: 'dependency-a', value: {"v"=>1}, "version-old": 0, "version-new": 10)
		@client.send(action: 'object-patch', id: 'dependency-b', value: {"v"=>1}, "version-old": 0, "version-new": 11)
		expect(@client.messages).to eq([{"action"=>"object-produce", "id"=>"test-object-1", "version-inferred"=>{"dependency-a"=>10, "dependency-b"=>11}}])
		@client.send(action: 'object-patch', id: 'test-object-1', value: {"v"=>2}, "version-old": 0, "version-new": {"dependency-a"=>10})
		expect(@client.messages).to eq([{"action"=>"object-update", "id"=>"test-object-1", "version-old"=>{"dependency-a"=>10, "dependency-b"=>10}, "version-new"=>{"dependency-a"=>10}, "patch"=>[{"op"=>"replace", "path"=>"/v", "value"=>2}]}])
	end


	it "crashes when upgrading version from integer to hash" do
		@client.send(action: 'object-producer-register', pattern: 'test-object-1')
		@client.send(action: 'object-consumer-register', pattern: 'test-object-1')
		expect(@client.messages).to eq([{"action"=>"object-produce", "id"=>"test-object-1", "version-inferred"=>nil}])
		@client.send(action: 'object-patch', id: 'test-object-1', value: {"v"=>1}, "version-old": 0, "version-new": 1)
		expect(@client.messages).to eq([{"action"=>"object-update", "id"=>"test-object-1", "version-old"=>0, "version-new"=>1, "value"=>{"v"=>1}}])
		@client.send(action: 'object-patch', id: 'test-object-1', value: {"v"=>1}, "version-old": 1, "version-new": {"dependency-a"=>10, "dependency-b"=>10})
		expect(@client.messages).to eq([{"action"=>"object-update", "id"=>"test-object-1", "version-old"=>1, "version-new"=>{"dependency-a"=>10, "dependency-b"=>10}, "patch"=>[]}])
	end


	it "crashes because it accepted integer version_needed when already owning hash version_needed" do
		@client.send(action: 'object-producer-register', pattern: 'test-object-1')
		@client.send(action: 'object-consumer-register', pattern: 'test-object-1')
		expect(@client.messages).to eq([{"action"=>"object-produce", "id"=>"test-object-1", "version-inferred"=>nil}])
		@client.send(action: 'object-patch', id: 'test-object-1', value: {"v"=>1}, "version-old": 0, "version-new": {"test-object-2" => 0})
		expect(@client.messages).to eq([{"action"=>"object-update", "id"=>"test-object-1", "version-old"=>0, "version-new"=>{"test-object-2"=>0}, "value"=>{"v"=>1}}])
		@client2 = Client.new(@server)
		@client2.send(action: 'object-producer-register', pattern: 'test-object-1', "known-version" => 2)
		expect(@client2.messages).to eq([])
		@client.send(action: 'object-patch', id: 'test-object-2', value: {"v"=>1}, "version-old": 0, "version-new": 2)
		expect(@client2.messages).to eq([])
		expect(@client.messages).to eq([{"action"=>"object-produce", "id"=>"test-object-1", "version-inferred"=>{"test-object-2"=>2}}])
	end


	it "accepts lower version" do
		@client.send(action: 'object-producer-register', pattern: 'test-object-1')
		@client.send(action: 'object-consumer-register', pattern: 'test-object-1')
		expect(@client.messages).to eq([{"action"=>"object-produce", "id"=>"test-object-1", "version-inferred"=>nil}])
		@client.send(action: 'object-patch', id: 'test-object-1', value: {"v"=>1}, "version-old": 0, "version-new": 2)
		expect(@client.messages).to eq([{"action"=>"object-update", "id"=>"test-object-1", "version-old"=>0, "version-new"=>2, "value"=>{"v"=>1}}])
		@client.send(action: 'object-patch', id: 'test-object-1', value: {"v"=>2}, "version-old": 0, "version-new": 1)
		expect(@client.messages).to eq([])
	end


	it "tries to despawn object on wildcard consumer disconnect if only remaining reason to stay alive is dependency" do
		@client2 = Client.new(@server)
		@client.send(action: 'object-consumer-register', pattern: 'test-object-1', latest_known_version: 0)
		@client.send(action: 'object-consumer-register', pattern: 'test-object-2', latest_known_version: 0)
		@client2.send(action: 'object-consumer-register', pattern: 'test-object-*', latest_known_version: 0)
		@client.send(action: 'object-producer-register', pattern: 'test-object-1')
		@client.send(action: 'object-producer-register', pattern: 'test-object-2')
		expect(@client.messages).to eq([{"action"=>"object-produce", "id"=>"test-object-1", "version-inferred"=>nil}])
		@client.send(action: 'object-patch', id: 'test-object-1', value: {"v"=>1}, "version-old": 0, "version-new": {"test-object-2"=>2})
		expect(@client2.messages).to eq([{"action"=>"object-update", "id"=>"test-object-1", "version-old"=>0, "version-new"=>{"test-object-2"=>2}, "value"=>{"v"=>1}}])
		expect(@client.messages).to eq([{"action"=>"object-update", "id"=>"test-object-1", "version-old"=>0, "version-new"=>{"test-object-2"=>2}, "value"=>{"v"=>1}}, {"action"=>"object-produce", "id"=>"test-object-2", "version-inferred"=>nil}])
		@client.send(action: 'object-patch', id: 'test-object-2', value: {"x"=>2}, "version-old": 0, "version-new": 1)
		expect(@client2.messages).to eq([{"action"=>"object-update", "id"=>"test-object-2", "version-old"=>0, "version-new"=>1, "value"=>{"x"=>2}}])
		expect(@client.messages).to eq([{"action"=>"object-update", "id"=>"test-object-2", "version-old"=>0, "version-new"=>1, "value"=>{"x"=>2}}])
		@client.send(action: 'object-consumer-unregister', pattern: 'test-object-2')
		expect(@client.messages).to eq([])
		@client.send(action: 'object-producer-unregister', pattern: 'test-object-2')
		expect(@client.messages).to eq([])
		@client2.send(action: 'object-consumer-unregister', pattern: 'test-object-*')
		expect(@client2.messages).to eq([]) #<RuntimeError: Despawning object that should stay alive>
		@client2.send(action: 'object-consumer-register', pattern: 'test-object-2', latest_known_version: 0)
		expect(@client.messages).to eq([])
		expect(@client2.messages).to eq([{"action"=>"object-update", "id"=>"test-object-2", "version-old"=>0, "version-new"=>1, "value"=>{"x"=>2}}])
	end


	it "tries to despawn object on wildcard producer disconnect if only remaining reason to stay alive is dependency" do
		@client2 = Client.new(@server)
		@client.send(action: 'object-consumer-register', pattern: 'test-object-1', latest_known_version: 0)
		@client.send(action: 'object-consumer-register', pattern: 'test-object-2', latest_known_version: 0)
		@client2.send(action: 'object-producer-register', pattern: 'test-object-*', latest_known_version: 0)
		expect(@client2.messages).to eq([{"action"=>"object-produce", "id"=>"test-object-1", "version-inferred"=>nil}])
		expect(@client.messages).to eq([])
		@client2.send(action: 'object-patch', id: 'test-object-1', value: {"v"=>1}, "version-old": 0, "version-new": {"test-object-2"=>2})
		expect(@client2.messages).to eq([{"action"=>"object-produce", "id"=>"test-object-2", "version-inferred"=>nil}])
		expect(@client.messages).to eq([{"action"=>"object-update", "id"=>"test-object-1", "version-old"=>0, "version-new"=>{"test-object-2"=>2}, "value"=>{"v"=>1}}])
		@client2.send(action: 'object-patch', id: 'test-object-2', value: {"x"=>2}, "version-old": 0, "version-new": 1)
		expect(@client2.messages).to eq([])
		expect(@client.messages).to eq([{"action"=>"object-update", "id"=>"test-object-2", "version-old"=>0, "version-new"=>1, "value"=>{"x"=>2}}])
		@client.send(action: 'object-consumer-unregister', pattern: 'test-object-2')
		expect(@client.messages).to eq([])
		@client2.send(action: 'object-producer-unregister', pattern: 'test-object-*')
		expect(@client2.messages).to eq([]) #<RuntimeError: Despawning object that should stay alive>
		@client2.send(action: 'object-consumer-register', pattern: 'test-object-2', latest_known_version: 0)
		expect(@client.messages).to eq([])
		expect(@client2.messages).to eq([{"action"=>"object-update", "id"=>"test-object-2", "version-old"=>0, "version-new"=>1, "value"=>{"x"=>2}}])
	end


#	it "crashes upon receiving a nil version of object" do
#		@client.send(action: 'object-producer-register', pattern: 'test-object-1')
#		@client.send(action: 'object-consumer-register', pattern: 'test-object-1')
#		expect(@client.messages).to eq([{"action"=>"object-produce", "id"=>"test-object-1", "version-inferred"=>nil}])
#		@client.send(action: 'object-patch', id: 'test-object-1', value: {"v"=>1}, "version-old": 0, "version-new": nil)
#		expect(@client.messages).to eq([{"action"=>"object-produce", "id"=>"test-object-1", "version-inferred"=>nil}])
#		@client.send(action: 'object-patch', id: 'test-object-1', value: {"v"=>2}, "version-old": 0, "version-new": 1)
#		expect(@client.messages).to eq([{"action"=>"object-update", "id"=>"test-object-1", "version-old"=>0, "version-new"=>1, "value"=>{"v"=>2}}])
#	end


#	it "crashes upon receiving a nil sub-version of object" do
#		@client.send(action: 'object-producer-register', pattern: 'test-object-1')
#		@client.send(action: 'object-consumer-register', pattern: 'test-object-1')
#		expect(@client.messages).to eq([{"action"=>"object-produce", "id"=>"test-object-1", "version-inferred"=>nil}])
#		@client.send(action: 'object-patch', id: 'test-object-1', value: {"v"=>1}, "version-old": 0, "version-new": nil)
#		expect(@client.messages).to eq([{"action"=>"object-produce", "id"=>"test-object-1", "version-inferred"=>nil}])
#		@client.send(action: 'object-patch', id: 'test-object-1', value: {"v"=>2}, "version-old": 0, "version-new": 1)
#		expect(@client.messages).to eq([{"action"=>"object-update", "id"=>"test-object-1", "version-old"=>0, "version-new"=>1, "value"=>{"v"=>2}}])
#	end


#	it "doesn't accept valid nested version" do
#		@client.send(action: 'object-consumer-register', pattern: 'test-object', latest_known_version: 0)
#		@client.send(action: 'object-producer-register', pattern: 'test-object')
#		expect(@client.messages).to eq([{"action"=>"object-produce", "id"=>"test-object", "version-inferred"=>nil}])
#		@client.send(action: 'object-patch', id: 'test-object', value: {"v"=>1}, "version-old": 0, "version-new": {"a"=>0, "b"=>0})
#		expect(@client.messages).to eq([{"action"=>"object-update", "id"=>"test-object", "version-old"=>0, "version-new"=>{"a"=>0, "b"=>0}, "value"=>{"v"=>1}}])
#		@client.send(action: 'object-patch', id: 'a', value: {"v"=>1}, "version-old": 0, "version-new": 2)
#		expect(@client.messages).to eq([{"action"=>"object-produce", "id"=>"test-object", "version-inferred"=>{"a"=>2, "b"=>0}}])
#		@client.send(action: 'object-patch', id: 'test-object', value: {"v"=>2}, "version-old": 0, "version-new": {"a"=>{"x"=>1}, })
#		expect(@client.messages).to eq([])
#	end



end
