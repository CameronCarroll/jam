require "./spec_helper"
require "../src/lmroutines"
require "../src/workspace"
require "../src/node"

# Mock for LlamaClient to avoid real API calls during tests
module LlamaClient
  class_property next_response : String = "Default response"
  class_property work_responses : Array(String) = [] of String
  class_property reflection_response : String = "Reflection response"
  
  def self.send_text(prompt : String, model : String, api_url : String = "http://localhost:11434/api/generate")
    if prompt.includes?(LMRoutines::REFLECTION_PROMPT)
      return @@reflection_response
    elsif !@@work_responses.empty?
      return @@work_responses.shift
    else
      return @@next_response
    end
  end
end

# Setup test config path for LMRoutines specs
LM_CONFIG_FILE_TEST = "test_config_lmroutines.json"

describe LMRoutines do
  config_path = Path.new(LM_CONFIG_FILE_TEST)

  describe "#command_history_tracking" do
    it "tracks commands executed by the LM" do
      # Set up workspace with a test node
      workspace = Workspace.new("Test Workspace", config_path)
      node1 = Node.new("Node 1", "Description 1", "node_id_1")
      workspace.add_node(node1)
      workspace.save_config
      
      # Set up LlamaClient mock responses
      # Set responses for the sequence of model interactions
      LlamaClient.next_response = "I'll help you work with your nodes. <JSON_CMD>{\"action\": \"list_nodes\", \"parameters\": {}}<END_JSON_CMD>"
      
      # Create a command history manually to test the output logic
      command_history = [
        {"action" => JSON::Any.new("list_nodes"), "parameters" => JSON.parse("{}")},
        {"action" => JSON::Any.new("add_node"), "parameters" => JSON.parse("{\"name\": \"Node 2\", \"description\": \"A second node\"}")},
        {"action" => JSON::Any.new("get_node"), "parameters" => JSON.parse("{\"index\": 1}")}
      ]
      
      # Test the formatting of command history output
      output = String.build do |io|
        LMRoutines.print_command_history(command_history, io)
      end
      
      # Skip color codes in the verification since they'll be different in colorized output
      # Just check for the key content parts
      output.should contain("Command History")
      output.should contain("list_nodes")
      output.should contain("add_node")
      output.should contain("name: Node 2")
      output.should contain("description: A second node")
      output.should contain("get_node")
      output.should contain("index: 1")
      
      # Clean up
      File.delete(LM_CONFIG_FILE_TEST) if File.exists?(LM_CONFIG_FILE_TEST)
    end
  end

  describe "#process_json_commands" do
    describe "node access methods" do
      after_each do
        File.delete(LM_CONFIG_FILE_TEST) if File.exists?(LM_CONFIG_FILE_TEST)
      end
      
      it "gets a node by its display index" do
        workspace = Workspace.new("Test Workspace", config_path)
        node1 = Node.new("Node 1", "Description 1", "node_id_1")
        node2 = Node.new("Node 2", "Description 2", "node_id_2")
        node3 = Node.new("Node 3", "Description 3", "node_id_3")
        workspace.add_node(node1)
        workspace.add_node(node2)
        workspace.add_node(node3)
        workspace.save_config

        json_cmd = {
          "action" => "get_node",
          "parameters" => {
            "index" => 1
          }
        }.to_json

        response = "Let me get that node: <JSON_CMD>#{json_cmd}<END_JSON_CMD>"
        result = LMRoutines.process_json_commands(response, workspace)

        result.should_not be_nil
        result.not_nil!.should contain(node2.name)
        result.not_nil!.should contain(node2.description)
      end

      it "gets a node by its ID" do
        workspace = Workspace.new("Test Workspace", config_path)
        node1 = Node.new("Node 1", "Description 1", "node_id_1")
        node2 = Node.new("Node 2", "Description 2", "node_id_2")
        node3 = Node.new("Node 3", "Description 3", "node_id_3")
        workspace.add_node(node1)
        workspace.add_node(node2)
        workspace.add_node(node3)
        workspace.save_config
        
        json_cmd = {
          "action" => "get_node",
          "parameters" => {
            "id" => "node_id_3"
          }
        }.to_json

        response = "Let me get that node: <JSON_CMD>#{json_cmd}<END_JSON_CMD>"
        result = LMRoutines.process_json_commands(response, workspace)

        result.should_not be_nil
        result.not_nil!.should contain(node3.name)
        result.not_nil!.should contain(node3.description)
      end

      it "returns an error when getting a node with an invalid index" do
        workspace = Workspace.new("Test Workspace", config_path)
        node1 = Node.new("Node 1", "Description 1", "node_id_1")
        workspace.add_node(node1)
        workspace.save_config
        
        json_cmd = {
          "action" => "get_node",
          "parameters" => {
            "index" => 99
          }
        }.to_json

        response = "Let me get that node: <JSON_CMD>#{json_cmd}<END_JSON_CMD>"
        result = LMRoutines.process_json_commands(response, workspace)

        result.should_not be_nil
        result.not_nil!.should contain("not found")
      end

      it "returns an error when getting a node with an invalid ID" do
        workspace = Workspace.new("Test Workspace", config_path)
        node1 = Node.new("Node 1", "Description 1", "node_id_1")
        workspace.add_node(node1)
        workspace.save_config
        
        json_cmd = {
          "action" => "get_node",
          "parameters" => {
            "id" => "non_existent_id"
          }
        }.to_json

        response = "Let me get that node: <JSON_CMD>#{json_cmd}<END_JSON_CMD>"
        result = LMRoutines.process_json_commands(response, workspace)

        result.should_not be_nil
        result.not_nil!.should contain("not found")
      end

      it "updates a node by its display index" do
        workspace = Workspace.new("Test Workspace", config_path)
        node1 = Node.new("Node 1", "Description 1", "node_id_1")
        workspace.add_node(node1)
        workspace.save_config
        
        json_cmd = {
          "action" => "update_node",
          "parameters" => {
            "index" => 0,
            "name" => "Updated Node 1",
            "description" => "Updated Description 1"
          }
        }.to_json

        response = "Let me update that node: <JSON_CMD>#{json_cmd}<END_JSON_CMD>"
        result = LMRoutines.process_json_commands(response, workspace)

        result.should_not be_nil
        result.not_nil!.should contain("updated")
        
        # Verify the node was actually updated
        updated_node = workspace.get_node_by_index(0)
        updated_node.should_not be_nil
        updated_node.not_nil!.name.should eq("Updated Node 1")
        updated_node.not_nil!.description.should eq("Updated Description 1")
      end

      it "updates a node by its ID" do
        workspace = Workspace.new("Test Workspace", config_path)
        node1 = Node.new("Node 1", "Description 1", "node_id_1")
        node2 = Node.new("Node 2", "Description 2", "node_id_2")
        workspace.add_node(node1)
        workspace.add_node(node2)
        workspace.save_config
        
        json_cmd = {
          "action" => "update_node",
          "parameters" => {
            "id" => "node_id_2",
            "name" => "Updated Node 2",
            "description" => "Updated Description 2"
          }
        }.to_json

        response = "Let me update that node: <JSON_CMD>#{json_cmd}<END_JSON_CMD>"
        result = LMRoutines.process_json_commands(response, workspace)

        result.should_not be_nil
        result.not_nil!.should contain("updated")
        
        # Verify the node was actually updated
        updated_node = workspace.get_node_by_id("node_id_2")
        updated_node.should_not be_nil
        updated_node.not_nil!.name.should eq("Updated Node 2")
        updated_node.not_nil!.description.should eq("Updated Description 2")
      end

      it "deletes a node by its display index" do
        workspace = Workspace.new("Test Workspace", config_path)
        node1 = Node.new("Node 1", "Description 1", "node_id_1")
        node2 = Node.new("Node 2", "Description 2", "node_id_2")
        workspace.add_node(node1)
        workspace.add_node(node2)
        workspace.save_config
        
        # First count the nodes
        initial_node_count = workspace.nodes.size
        
        json_cmd = {
          "action" => "delete_node",
          "parameters" => {
            "index" => 1
          }
        }.to_json

        response = "Let me delete that node: <JSON_CMD>#{json_cmd}<END_JSON_CMD>"
        result = LMRoutines.process_json_commands(response, workspace)

        result.should_not be_nil
        result.not_nil!.should contain("deleted")
        
        # Verify the node was actually deleted
        workspace.nodes.size.should eq(initial_node_count - 1)
        workspace.get_node_by_id("node_id_2").should be_nil
      end

      it "deletes a node by its ID" do
        workspace = Workspace.new("Test Workspace", config_path)
        node1 = Node.new("Node 1", "Description 1", "node_id_1")
        node2 = Node.new("Node 2", "Description 2", "node_id_2")
        node3 = Node.new("Node 3", "Description 3", "node_id_3")
        workspace.add_node(node1)
        workspace.add_node(node2)
        workspace.add_node(node3)
        workspace.save_config
        
        # First count the nodes
        initial_node_count = workspace.nodes.size
        
        json_cmd = {
          "action" => "delete_node",
          "parameters" => {
            "id" => "node_id_3"
          }
        }.to_json

        response = "Let me delete that node: <JSON_CMD>#{json_cmd}<END_JSON_CMD>"
        result = LMRoutines.process_json_commands(response, workspace)

        result.should_not be_nil
        result.not_nil!.should contain("deleted")
        
        # Verify the node was actually deleted
        workspace.nodes.size.should eq(initial_node_count - 1)
        workspace.get_node_by_id("node_id_3").should be_nil
      end

      it "adds a relationship between nodes using display indices" do
        workspace = Workspace.new("Test Workspace", config_path)
        node1 = Node.new("Node 1", "Description 1", "node_id_1")
        node2 = Node.new("Node 2", "Description 2", "node_id_2")
        node3 = Node.new("Node 3", "Description 3", "node_id_3")
        workspace.add_node(node1)
        workspace.add_node(node2)
        workspace.add_node(node3)
        workspace.save_config
        
        json_cmd = {
          "action" => "add_relationship",
          "parameters" => {
            "parent_index" => 0,
            "child_index" => 2
          }
        }.to_json

        response = "Let me create a relationship: <JSON_CMD>#{json_cmd}<END_JSON_CMD>"
        result = LMRoutines.process_json_commands(response, workspace)

        result.should_not be_nil
        result.not_nil!.should contain("added")
        
        # Verify the relationship was created
        parent = workspace.get_node_by_index(0)
        child = workspace.get_node_by_index(2)
        
        parent.should_not be_nil
        child.should_not be_nil
        parent.not_nil!.successors.should contain(child.not_nil!.id)
        child.not_nil!.predecessors.should contain(parent.not_nil!.id)
      end

      it "adds a relationship between nodes using IDs" do
        workspace = Workspace.new("Test Workspace", config_path)
        node1 = Node.new("Node 1", "Description 1", "node_id_1")
        node2 = Node.new("Node 2", "Description 2", "node_id_2")
        workspace.add_node(node1)
        workspace.add_node(node2)
        workspace.save_config
        
        json_cmd = {
          "action" => "add_relationship",
          "parameters" => {
            "parent_id" => "node_id_1",
            "child_id" => "node_id_2"
          }
        }.to_json

        response = "Let me create a relationship: <JSON_CMD>#{json_cmd}<END_JSON_CMD>"
        result = LMRoutines.process_json_commands(response, workspace)

        result.should_not be_nil
        result.not_nil!.should contain("added")
        
        # Verify the relationship was created
        parent = workspace.get_node_by_id("node_id_1")
        child = workspace.get_node_by_id("node_id_2")
        
        parent.should_not be_nil
        child.should_not be_nil
        parent.not_nil!.successors.should contain(child.not_nil!.id)
        child.not_nil!.predecessors.should contain(parent.not_nil!.id)
      end
    end
    
    it "returns nil if no JSON command is found" do
      workspace = Workspace.new("Test Workspace", Path.new("test_config.json"))
      response = "This is a normal response with no commands"
      
      result = LMRoutines.process_json_commands(response, workspace)
      result.should be_nil
    end
    
    it "processes list_nodes command correctly" do
      workspace = Workspace.new("Test Workspace", Path.new("test_config.json"))
      node = Node.new(name: "Test Node", description: "Test Description")
      workspace.add_node(node)
      
      response = "Here's what I found: <JSON_CMD>{\"action\": \"list_nodes\", \"parameters\": {}}<END_JSON_CMD>"
      
      result = LMRoutines.process_json_commands(response, workspace)
      result.should_not be_nil
      result.not_nil!.should contain("Node list:")
      result.not_nil!.should contain("Test Node")
    end
    
    it "processes add_node command correctly" do
      workspace = Workspace.new("Test Workspace", Path.new("test_config.json"))
      response = "Let me create a node for you: <JSON_CMD>{\"action\": \"add_node\", \"parameters\": {\"name\": \"New Node\", \"description\": \"New Description\"}}<END_JSON_CMD>"
      
      result = LMRoutines.process_json_commands(response, workspace)
      result.should_not be_nil
      result.not_nil!.should contain("Node added: New Node")
      
      # Verify the node was actually added
      workspace.nodes.size.should eq(1)
      workspace.nodes.first.name.should eq("New Node")
      workspace.nodes.first.description.should eq("New Description")
    end
    
    it "processes get_node command correctly" do
      workspace = Workspace.new("Test Workspace", Path.new("test_config.json"))
      node = Node.new(name: "Test Node", description: "Test Description")
      workspace.add_node(node)
      
      response = "Let me get that node: <JSON_CMD>{\"action\": \"get_node\", \"parameters\": {\"id\": \"#{node.id}\"}}<END_JSON_CMD>"
      
      result = LMRoutines.process_json_commands(response, workspace)
      result.should_not be_nil
      result.not_nil!.should contain("Test Node")
      result.not_nil!.should contain(node.id)
    end
    
    it "processes update_node command correctly" do
      workspace = Workspace.new("Test Workspace", Path.new("test_config.json"))
      node = Node.new(name: "Original Name", description: "Original Description")
      workspace.add_node(node)
      
      response = "Let me update that node: <JSON_CMD>{\"action\": \"update_node\", \"parameters\": {\"id\": \"#{node.id}\", \"name\": \"Updated Name\", \"description\": \"Updated Description\"}}<END_JSON_CMD>"
      
      result = LMRoutines.process_json_commands(response, workspace)
      result.should_not be_nil
      result.not_nil!.should contain("Node updated")
      
      # Verify the node was actually updated
      workspace.nodes.first.name.should eq("Updated Name")
      workspace.nodes.first.description.should eq("Updated Description")
    end
    
    it "processes delete_node command correctly" do
      workspace = Workspace.new("Test Workspace", Path.new("test_config.json"))
      node = Node.new(name: "Test Node", description: "Test Description")
      workspace.add_node(node)
      
      response = "Let me delete that node: <JSON_CMD>{\"action\": \"delete_node\", \"parameters\": {\"id\": \"#{node.id}\"}}<END_JSON_CMD>"
      
      result = LMRoutines.process_json_commands(response, workspace)
      result.should_not be_nil
      result.not_nil!.should contain("Node deleted")
      
      # Verify the node was actually deleted
      workspace.nodes.should be_empty
    end
    
    it "processes add_relationship command correctly" do
      workspace = Workspace.new("Test Workspace", Path.new("test_config.json"))
      parent = Node.new(name: "Parent Node", description: "Parent Description")
      child = Node.new(name: "Child Node", description: "Child Description")
      workspace.add_node(parent)
      workspace.add_node(child)
      
      response = "Let me create a relationship: <JSON_CMD>{\"action\": \"add_relationship\", \"parameters\": {\"parent_id\": \"#{parent.id}\", \"child_id\": \"#{child.id}\"}}<END_JSON_CMD>"
      
      result = LMRoutines.process_json_commands(response, workspace)
      result.should_not be_nil
      result.not_nil!.should contain("Relationship added")
      
      # Verify the relationship was actually created
      parent.successors.should contain(child.id)
      child.predecessors.should contain(parent.id)
    end
    
    it "handles malformed JSON commands" do
      workspace = Workspace.new("Test Workspace", Path.new("test_config.json"))
      response = "This has a bad command: <JSON_CMD>{\"action\": \"list_nodes\", \"parameters\": {}<END_JSON_CMD>"
      
      result = LMRoutines.process_json_commands(response, workspace)
      result.should_not be_nil
      result.not_nil!.should contain("Error processing command")
    end
    
    it "handles unknown commands" do
      workspace = Workspace.new("Test Workspace", Path.new("test_config.json"))
      response = "Let me try an unknown command: <JSON_CMD>{\"action\": \"unknown_command\", \"parameters\": {}}<END_JSON_CMD>"
      
      result = LMRoutines.process_json_commands(response, workspace)
      result.should_not be_nil
      result.not_nil!.should contain("Unknown command")
    end
    
    it "processes generate_plan command correctly" do
      workspace = Workspace.new("Test Workspace", Path.new("test_config.json"))
      node1 = Node.new(name: "Task 1", description: "First task")
      node2 = Node.new(name: "Task 2", description: "Second task")
      workspace.add_node(node1)
      workspace.add_node(node2)
      workspace.add_relationship(node1.id, node2.id)
      
      response = "Let me generate a plan: <JSON_CMD>{\"action\": \"generate_plan\", \"parameters\": {}}<END_JSON_CMD>"
      
      result = LMRoutines.process_json_commands(response, workspace)
      result.should_not be_nil
      result.not_nil!.should contain("Command result for 'generate_plan'")
    end
    
    it "processes show_dependencies command correctly" do
      workspace = Workspace.new("Test Workspace", Path.new("test_config.json"))
      node1 = Node.new(name: "Task 1", description: "First task")
      node2 = Node.new(name: "Task 2", description: "Second task")
      workspace.add_node(node1)
      workspace.add_node(node2)
      workspace.add_relationship(node1.id, node2.id)
      
      response = "Let me show dependencies: <JSON_CMD>{\"action\": \"show_dependencies\", \"parameters\": {}}<END_JSON_CMD>"
      
      result = LMRoutines.process_json_commands(response, workspace)
      result.should_not be_nil
      result.not_nil!.should contain("Command result for 'show_dependencies'")
    end
  end
  
  describe "multiple commands in a single response" do
    it "processes only the first command found" do
      workspace = Workspace.new("Test Workspace", Path.new("test_config.json"))
      
      response = "Here are multiple commands: <JSON_CMD>{\"action\": \"add_node\", \"parameters\": {\"name\": \"First Node\", \"description\": \"First Description\"}}<END_JSON_CMD> and <JSON_CMD>{\"action\": \"add_node\", \"parameters\": {\"name\": \"Second Node\", \"description\": \"Second Description\"}}<END_JSON_CMD>"
      
      result = LMRoutines.process_json_commands(response, workspace)
      result.should_not be_nil
      result.not_nil!.should contain("Node added: First Node")
      
      # Verify only the first node was added
      workspace.nodes.size.should eq(1)
      workspace.nodes.first.name.should eq("First Node")
    end
  end
end