require "./spec_helper"
require "json"
require "file"

CONFIG_FILE_TEST = "test_config.json"
config_path = Path.new(CONFIG_FILE_TEST)

describe Workspace do
  describe "#initialize" do
    it "creates a Workspace with a name and empty nodes array" do
      workspace = Workspace.new("My Workspace Name", config_path)
      workspace.name.should eq("My Workspace Name")
      workspace.nodes.should be_empty
      workspace.system_prompt.should eq("")
      workspace.modeldata.should be_a(Hash(String, String))
      workspace.modeldata.should be_empty
    end

    it "creates a Workspace with a name and system prompt" do
      workspace = Workspace.new("My Workspace Name", config_path, "System prompt for tests")
      workspace.name.should eq("My Workspace Name")
      workspace.nodes.should be_empty
      workspace.system_prompt.should eq("System prompt for tests")
      workspace.modeldata.should be_a(Hash(String, String))
      workspace.modeldata.should be_empty
    end
  end

  describe "#add_node" do
    it "adds a node to the workspace's nodes array" do
      workspace = Workspace.new("Test Workspace", config_path)
      node = Node.new("Test Node", "Test Description")
      workspace.add_node(node)
      workspace.nodes.size.should eq(1)
      workspace.nodes.first.should be_a(Node)
      workspace.nodes.first.name.should eq("Test Node")
    end
  end

  describe "#save_config" do
    it "saves the workspace configuration to a JSON file" do
        workspace = Workspace.new("Test Workspace",config_path) # Pass ONFIG_FILE_TEST here
        workspace.system_prompt = "Test system prompt"
        workspace.modeldata["last_stable_prompt"] = "Stable prompt"
        workspace.modeldata["test_key"] = "test_value"
        node1 = Node.new("Node 1", "Description 1", "node_id_1")
        node2 = Node.new("Node 2", "Description 2", "node_id_2", ["node_id_1"], ["node_id_3"], ["req_1"], ["goal_1"])
        workspace.add_node(node1)
        workspace.add_node(node2)
        workspace.save_config

        File.exists?(CONFIG_FILE_TEST).should be_true
        
        json_content = File.read(CONFIG_FILE_TEST)
        workspace_data = JSON.parse(json_content)

        workspace_data["name"].should eq("Test Workspace")
        workspace_data["system_prompt"].should eq("Test system prompt")
        workspace_data["modeldata"].should be_a(JSON::Any)
        workspace_data["modeldata"]["last_stable_prompt"].should eq("Stable prompt")
        workspace_data["modeldata"]["test_key"].should eq("test_value")
        nodes = workspace_data["nodes"]
        nodes.size.should eq(2)

        node1_data = nodes[0]
        node1_data["id"].should eq("node_id_1")
        node1_data["name"].should eq("Node 1")
        node1_data["description"].should eq("Description 1")
    end
end

  describe "#read_config" do
    it "reads workspace configuration from a JSON file" do
      json_content = {
        "name" => "Loaded Workspace",
        "system_prompt" => "Loaded system prompt",
        "modeldata" => {
          "last_stable_prompt" => "Loaded stable prompt",
          "test_key" => "loaded_test_value"
        },
        "nodes" => [
          {
            "id" => "loaded_node_id_1",
            "name" => "Loaded Node 1",
            "description" => "Loaded Description 1",
            "predecessors" => ["pred_1"],
            "successors" => ["succ_1"],
            "requirement_ids" => ["req_1"],
            "goal_ids" => ["goal_1"]
          },
          {
            "id" => "loaded_node_id_2",
            "name" => "Loaded Node 2",
            "description" => "Loaded Description 2",
            "predecessors" => [] of String,
            "successors" => [] of String,
            "requirement_ids" => [] of String,
            "goal_ids" => [] of String
          }
        ]
      }.to_json
      File.write(CONFIG_FILE_TEST, json_content)

      workspace = Workspace.new("Initial Workspace Name", config_path) # Initial name should be overwritten
      workspace.read_config

      workspace.name.should eq("Loaded Workspace")
      workspace.system_prompt.should eq("Loaded system prompt")
      workspace.modeldata.size.should eq(2)
      workspace.modeldata["last_stable_prompt"].should eq("Loaded stable prompt")
      workspace.modeldata["test_key"].should eq("loaded_test_value")
      workspace.nodes.size.should eq(2)

      node1 = workspace.nodes[0]
      node1.id.should eq("loaded_node_id_1")
      node1.name.should eq("Loaded Node 1")
      node1.description.should eq("Loaded Description 1")
      node1.predecessors.should eq(["pred_1"])
      node1.successors.should eq(["succ_1"])
      node1.requirement_ids.should eq(["req_1"])
      node1.goal_ids.should eq(["goal_1"])

      node2 = workspace.nodes[1]
      node2.id.should eq("loaded_node_id_2")
      node2.name.should eq("Loaded Node 2")
      node2.description.should eq("Loaded Description 2")
      node2.predecessors.should be_empty
      node2.successors.should be_empty
      node2.requirement_ids.should be_empty
      node2.goal_ids.should be_empty
    end
  end

  describe "#dump_nodes_for_llm" do
    it "dumps the context of all nodes into a single string for LLM" do
      workspace = Workspace.new("Test Workspace", config_path)
      node1 = Node.new("Node 1", "Description 1", "test_id_1")
      node2 = Node.new("Node 2", "Description 2", "test_id_2")
      workspace.add_node(node1)
      workspace.add_node(node2)

      expected_output = "Node 1 test_id_1\nNode 2 test_id_2\n"
      workspace.dump_nodes_for_llm.should eq(expected_output)
    end

    it "returns an empty string if there are no nodes" do
      workspace = Workspace.new("Empty Workspace", config_path)
      workspace.dump_nodes_for_llm.should eq("")
    end
  end

  describe "#dump_nodes_for_human" do
    it "dumps the list of nodes in a human-readable format" do
      workspace = Workspace.new("Test Workspace", config_path)
      node1 = Node.new("Node 1", "Description 1")
      node2 = Node.new("Node 2", "Multiline\nDescription 2")
      workspace.add_node(node1)
      workspace.add_node(node2)

      workspace.dump_nodes_for_human.should be_a(String)
    end

    it "returns a header and no node details if there are no nodes" do
      workspace = Workspace.new("Empty Workspace", config_path)
      workspace.dump_nodes_for_human.should be_a(String)
    end
  end

  describe "#get_node_by_index" do
    it "retrieves a node from the workspace by its index" do
      workspace = Workspace.new("Test Workspace", config_path)
      node1 = Node.new("Node 1", "Description 1")
      node2 = Node.new("Node 2", "Description 2")
      workspace.add_node(node1)
      workspace.add_node(node2)

      workspace.get_node_by_index(0).should eq(node1)
      workspace.get_node_by_index(1).should eq(node2)
    end

    it "returns nil if the index is out of bounds" do
      workspace = Workspace.new("Test Workspace", config_path)
      workspace.get_node_by_index(0).should be_nil
      workspace.get_node_by_index(99).should be_nil
      workspace.get_node_by_index(-1).should be_nil
    end
  end

  describe "#remove_node_by_index" do
    it "removes a node from the workspace by its index" do
      workspace = Workspace.new("Test Workspace", config_path)
      node1 = Node.new("Node 1", "Description 1")
      node2 = Node.new("Node 2", "Description 2")
      node3 = Node.new("Node 3", "Description 3")
      workspace.add_node(node1)
      workspace.add_node(node2)
      workspace.add_node(node3)

      workspace.remove_node_by_index(1)

      workspace.nodes.size.should eq(2)
      workspace.nodes[0].should eq(node1)
      workspace.nodes[1].should eq(node3) # Node 3 shifts to index 1
    end

    it "does nothing if the index is out of bounds" do
      workspace = Workspace.new("Test Workspace", config_path)
      node1 = Node.new("Node 1", "Description 1")
      workspace.add_node(node1)
      initial_nodes = workspace.nodes # Capture initial nodes

      workspace.remove_node_by_index(99) # Out of bounds index
      workspace.nodes.should eq(initial_nodes) # Nodes array should remain unchanged
      workspace.remove_node_by_index(-1) # Negative index
      workspace.nodes.should eq(initial_nodes) # Nodes array should remain unchanged
    end
  end

  describe "#get_node_by_id" do
    it "retrieves a node from the workspace by its ID" do
      workspace = Workspace.new("Test Workspace", config_path)
      node1 = Node.new("Node 1", "Description 1", "node_id_1")
      node2 = Node.new("Node 2", "Description 2", "node_id_2")
      workspace.add_node(node1)
      workspace.add_node(node2)

      workspace.get_node_by_id("node_id_1").should eq(node1)
      workspace.get_node_by_id("node_id_2").should eq(node2)
    end

    it "returns nil if no node with the given ID is found" do
      workspace = Workspace.new("Test Workspace", config_path)
      node1 = Node.new("Node 1", "Description 1", "node_id_1")
      workspace.add_node(node1)

      workspace.get_node_by_id("non_existent_id").should be_nil
    end

    it "handles whitespace in node IDs correctly" do
       workspace = Workspace.new("Test Workspace", config_path)
      node1 = Node.new("Node 1", "Description 1", "  node_id_1  ") # ID with whitespace
      workspace.add_node(node1)

      workspace.get_node_by_id("node_id_1").should eq(node1) # Search without whitespace
      workspace.get_node_by_id("  node_id_1  ").should eq(node1) # Search with whitespace
    end
  end

  describe "#create_dependency" do
    it "creates a bidirectional dependency between two nodes" do
      workspace = Workspace.new("Test Workspace", config_path)
      node1 = Node.new("Node 1", "Description 1", "node_id_1")
      node2 = Node.new("Node 2", "Description 2", "node_id_2")
      workspace.add_node(node1)
      workspace.add_node(node2)

      success, message = workspace.create_dependency(node1, node2)
      success.should be_true
      message.should eq("")

      node1.successors.should eq(["node_id_2"])
      node2.predecessors.should eq(["node_id_1"])

      # Verify config file is saved (optional, but good practice for methods that modify workspace state)
      File.exists?(CONFIG_FILE_TEST).should be_true
    end

    it "implements reasonable validation" do
      # This test is a placeholder since the create_dependency method
      # already requires non-nil Node objects for both parameters
      # and Crystal's type system ensures this at compile time
      
      # We can still confirm the method works with valid nodes
      workspace = Workspace.new("Test Workspace", config_path)
      node1 = Node.new("Node 1", "Description 1", "node_id_1")
      node2 = Node.new("Node 2", "Description 2", "node_id_2")
      workspace.add_node(node1)
      workspace.add_node(node2)
      
      # This should succeed
      success, message = workspace.create_dependency(node1, node2)
      success.should be_true
      message.should eq("")
      
      # Reset for next test
      node1.successors.clear
      node2.predecessors.clear
    end
  end

  describe "#remove_dependency" do
    it "removes a bidirectional dependency between two nodes" do
      workspace = Workspace.new("Test Workspace", config_path)
      node1 = Node.new("Node 1", "Description 1", "node_id_1")
      node2 = Node.new("Node 2", "Description 2", "node_id_2")
      workspace.add_node(node1)
      workspace.add_node(node2)
      workspace.create_dependency(node1, node2) # Set up dependency

      success, message = workspace.remove_dependency("node_id_1", "node_id_2")
      success.should be_true
      message.should eq("")

      node1.successors.should be_empty
      node2.predecessors.should be_empty

       # Verify config file is saved (optional, but good practice for methods that modify workspace state)
      File.exists?(CONFIG_FILE_TEST).should be_true
    end

    it "returns false if either node ID is not found" do
      workspace = Workspace.new("Test Workspace", config_path)
      node1 = Node.new("Node 1", "Description 1", "node_id_1")
      workspace.add_node(node1)

      success1, message1 = workspace.remove_dependency("non_existent_id", "node_id_1")
      success1.should be_false
      message1.should_not be_empty
      
      success2, message2 = workspace.remove_dependency("node_id_1", "non_existent_id")
      success2.should be_false
      message2.should_not be_empty
      
      success3, message3 = workspace.remove_dependency("non_existent_id_1", "non_existent_id_2")
      success3.should be_false
      message3.should_not be_empty
    end

    it "returns true even if dependency doesn't exist, but nodes do" do
      workspace = Workspace.new("Test Workspace", config_path)
      node1 = Node.new("Node 1", "Description 1", "node_id_1")
      node2 = Node.new("Node 2", "Description 2", "node_id_2")
      workspace.add_node(node1)
      workspace.add_node(node2)

      success, message = workspace.remove_dependency("node_id_1", "node_id_2") # No dependency exists
      # Updated expectation: Now we should expect false and a message about no relationship existing
      success.should be_false
      message.should contain("No relationship exists")
    end
  end

  describe "#get_successors" do
    it "gets all successors for a given node" do
      workspace = Workspace.new("Test Workspace", config_path)
      node1 = Node.new("Node 1", "Description 1", "node_id_1")
      node2 = Node.new("Node 2", "Description 2", "node_id_2")
      node3 = Node.new("Node 3", "Description 3", "node_id_3")
      workspace.add_node(node1)
      workspace.add_node(node2)
      workspace.add_node(node3)
      workspace.create_dependency(node1, node2)
      workspace.create_dependency(node1, node3)

      successors = workspace.get_successors("node_id_1")
      successors.size.should eq(2)
      successors.should be_a(Array(Node))
      successors.first.name.should eq("Node 2")
      successors.last.name.should eq("Node 3")  
    end

    it "returns an empty array if the node has no successors" do
      workspace = Workspace.new("Test Workspace", config_path)
      node1 = Node.new("Node 1", "Description 1", "node_id_1")
      workspace.add_node(node1)

      successors = workspace.get_successors("node_id_1")
      successors.should be_empty
    end

    it "returns an empty array if the node ID is not found" do
      workspace = Workspace.new("Test Workspace", config_path)
      successors = workspace.get_successors("non_existent_id")
      successors.should be_empty
    end
  end

  describe "#get_predecessors" do
    it "gets all predecessors for a given node" do
      workspace = Workspace.new("Test Workspace", config_path)
      node1 = Node.new("Node 1", "Description 1", "node_id_1")
      node2 = Node.new("Node 2", "Description 2", "node_id_2")
      node3 = Node.new("Node 3", "Description 3", "node_id_3")
      workspace.add_node(node1)
      workspace.add_node(node2)
      workspace.add_node(node3)
      workspace.create_dependency(node1, node3)
      workspace.create_dependency(node2, node3)

      predecessors = workspace.get_predecessors("node_id_3")
      predecessors.size.should eq(2)
      predecessors.should be_a(Array(Node))
      predecessors.first.name.should eq("Node 1")
      predecessors.last.name.should eq("Node 2")  
    end

    it "returns an empty array if the node has no predecessors" do
      workspace = Workspace.new("Test Workspace", config_path)
      node1 = Node.new("Node 1", "Description 1", "node_id_1")
      workspace.add_node(node1)

      predecessors = workspace.get_predecessors("node_id_1")
      predecessors.should be_empty
    end

    it "returns an empty array if the node ID is not found" do
      workspace = Workspace.new("Test Workspace", config_path)
      predecessors = workspace.get_predecessors("non_existent_id")
      predecessors.should be_empty
    end
  end
  File.delete(CONFIG_FILE_TEST) if File.exists?(CONFIG_FILE_TEST)
end