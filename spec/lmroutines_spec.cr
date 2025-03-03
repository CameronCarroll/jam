require "./spec_helper"
require "../src/lmroutines"
require "../src/workspace"
require "../src/node"

# Mock for LlamaClient to avoid real API calls during tests
module LlamaClient
  class_property next_response : String = "Default response"
  
  def self.send_text(prompt : String, model : String, api_url : String = "http://localhost:11434/api/generate")
    @@next_response
  end
end

describe LMRoutines do
  describe "#process_json_commands" do
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