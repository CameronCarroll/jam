class Error < Exception; end
class ConfigError < Error; end

# Represents a workspace that contains multiple nodes.
#
# A workspace is the top-level container for nodes and handles
# persistence, loading, and node management operations.
#
# Example:
#
# ```crystal
# workspace = Workspace.new("My Workspace")
# workspace.read_config(config_file_path)
# workspace.add_node(Node.new("Node A", "Description"))
# workspace.save_config
# ```
class Workspace
    # This workspace has a name.
    property name : String

    # Location of JSON config file
    property config_path : Path
  
    # Array of Node objects within this workspace.
    property nodes : Array(Node)

    # System prompt / workspace for LLM
    property system_prompt : String
  
    # Initializes a new Workspace
    def initialize(@name : String, @config_path : Path, @system_prompt = "")
      @name = name
      @config_path = config_path
      @system_prompt = system_prompt
      @nodes = [] of Node
    end
  
    # Adds a node to the workspace.
    def add_node(node : Node)
      @nodes << node
    end
  
    # Saves the workspace configuration to a JSON file.
    #
    # The configuration includes the name and description of each node
    # within the workspace. The data is saved to the file specified by `CONFIG_FILE`.
    #
    # See `CONFIG_FILE`
    def save_config

      workspace_data = {
        "name" => @name,
        "system_prompt" => @system_prompt,
        "nodes" => [] of Hash(String, String | Array(String))
      }
      nodes_array = workspace_data["nodes"].as(Array(Hash(String, String | Array(String))))
      @nodes.each do |node|
        nodes_array << {
            "id" => node.id,
            "name" => node.name,
            "description" => node.description,
            "predecessors" => node.predecessors,
            "successors" => node.successors,
            "requirement_ids" => node.requirement_ids,
            "goal_ids" => node.goal_ids
        }
      end
      workspace_data["nodes"] = nodes_array
      jason_content = workspace_data.to_json
  
      begin
        File.write(@config_path, jason_content)
        puts "Workspace config saved to config file #{CONFIG_FILE}"
      rescue e : File::Error
        puts "Error saving configuration: #{e}"
      end
    end

    # Reads config file, parses the JSON and loads workspace with node data.
    def read_config : Nil
      begin
        jason_content = File.read(@config_path)
        workspace_data = Hash(String, String | Array(Hash(String, String | Array(String)))).from_json(jason_content)

        raise ConfigError.new("Expected a hash for workspace config") unless workspace_data.is_a?(Hash)
        raise ConfigError.new("Expected a string for workspace name") unless workspace_data["name"].is_a?(String)
        @name = workspace_data["name"].to_s
        @system_prompt = workspace_data["system_prompt"].to_s
        raise ConfigError.new("Expected a string for system prompt") unless @system_prompt.is_a?(String)

        nodes_data = workspace_data["nodes"]
        raise ConfigError.new("Expected a nodes array in config") unless nodes_data.is_a?(Array)

        nodes_data.each do |hash|
          raise ConfigError.new("Expected an array of hashes for nodes") unless hash.is_a?(Hash)
          id = hash["id"]
          raise ConfigError.new("Expected a string ID for node") unless id.is_a?(String)
          name = hash["name"]
          raise ConfigError.new("Expected a string name for node") unless name.is_a?(String)
          description = hash["description"]
          raise ConfigError.new("Expected a string description for node") unless description.is_a?(String)
          predecessors = hash["predecessors"]
          raise ConfigError.new("Expected a an array of strings for node predecessors") unless predecessors.is_a?(Array(String))
          successors = hash["successors"]
          raise ConfigError.new("Expected a an array of strings for node successors") unless successors.is_a?(Array(String))
          requirement_ids = hash["requirement_ids"]
          raise ConfigError.new("Expected a an array of strings for node requirement_ids") unless requirement_ids.is_a?(Array(String))
          goal_ids = hash["goal_ids"]
          raise ConfigError.new("Expected a an array of strings for node goal_ids") unless goal_ids.is_a?(Array(String))

          node = Node.new(name, description, id, predecessors, successors, requirement_ids, goal_ids)
          self.add_node(node)
        end
      rescue e : ConfigError
        puts "Error loading config file: #{e}"
        puts "Config is located at: #{CONFIG_FILE}"
      rescue e : File::Error
        puts "Error reading/parsing JSON file: #{e}"
        puts "Problematic path: #{CONFIG_FILE}"
      end
    end
  
    # Dumps the context of all nodes into a single string.
    #
    # This method concatenates the name and description of each node
    # in the workspace. This can be used for providing context to language models.
    def dump_nodes_for_llm : String
      superbigstring = String.new
      @nodes.each do |node|
        superbigstring += node.name
        superbigstring += node.description
      end
      return superbigstring
    end
  
    # Dumps the list of nodes in a human-readable format.
    #
    # This method formats the node list with indices, names, and descriptions,
    # making it suitable for display in the command line interface.
    def dump_nodes_for_human : String
      superbigstring = String.new
      superbigstring += "Node list:\n"
      superbigstring += "-------------\n"
      @nodes.each.with_index do |node, index|
        superbigstring += "##{index}:\n"
        superbigstring += node.name
        superbigstring += "\n"
        superbigstring += node.description
        superbigstring += "\n-------------\n"
      end
      return superbigstring
    end
  
    # Retrieves a node from the workspace by its display index. (Not its ID!)
    #
    # Returns the node at the given index, or `nil` if the index is invalid.
    # The index corresponds to the order in which nodes are displayed to the user. This is also the order in which nodes are listed in the JSON file.
    # See `dump_nodes_for_human`.
    def get_node_by_index(index : Int) : Node?
      return @nodes[index]?  
    end
  
    # Removes a node from the workspace by its display index (Not its ID! See `get_node_by_index`)
    def remove_node_by_index(index : Int)
      if @nodes[index]?
        @nodes.delete_at(index)
      end
    end
   
    # Gets a node by ID from our workspace nodes list
    #
    # Returns the node if found, or `nil` if not found.
    def get_node_by_id(id : String) : Node?
      id = id.gsub(" ") {""}
      @nodes.find { |node| node.id.strip == id }
    end

    # Create a bidirectional dependency between two nodes
    #
    # Returns a tuple with success status and error message (if any).
    def create_dependency(predecessor : Node, successor : Node) : Tuple(Bool, String)
      return {false, "Predecessor node is nil"} unless predecessor
      return {false, "Successor node is nil"} unless successor
      
      # Check if relationship already exists
      if predecessor.successors.includes?(successor.id)
        return {false, "Relationship already exists between '#{predecessor.name}' and '#{successor.name}'"}
      end
      
      # Add the relationship
      predecessor.add_successor(successor.id)
      successor.add_predecessor(predecessor.id)

      save_config
      return {true, ""}
    end

    # Remove a bidirectional dependency between two nodes
    #
    # Returns a tuple with success status and error message (if any).
    def remove_dependency(predecessor_id : String, successor_id : String) : Tuple(Bool, String)
      predecessor = get_node_by_id(predecessor_id)
      successor = get_node_by_id(successor_id)
      
      return {false, "Predecessor node with ID '#{predecessor_id}' not found"} unless predecessor
      return {false, "Successor node with ID '#{successor_id}' not found"} unless successor
      
      # Check if relationship exists
      unless predecessor.successors.includes?(successor_id)
        return {false, "No relationship exists between '#{predecessor.name}' and '#{successor.name}'"}
      end
      
      # Remove the bi-directional relationship
      predecessor.remove_successor(successor_id)
      successor.remove_predecessor(predecessor_id)
      
      save_config  # Save changes to config
      return {true, ""}
    end

    # Get all successors for a given node
    #
    # Returns a list of successor node objects.
    def get_successors(id : String) : Array(Node)
      node = get_node_by_id(id)
      return [] of Node unless node

      node.successors.compact_map { |id| get_node_by_id(id) }
    end

    # Get all predecessors for a given node
    #
    # Returns a list of predecessor node objects.
    def get_predecessors(id : String) : Array(Node)
      node = get_node_by_id(id)
      return [] of Node unless node
      
      node.predecessors.compact_map { |id| get_node_by_id(id) }
    end
    
    # Removes a node from the workspace by its index
    #
    # Returns a tuple with success status and error message (if any).
    def remove_node(index : Int) : Tuple(Bool, String)
      if node = get_node_by_index(index)
        # Get the ID for reference removal
        node_id = node.id
        
        # Remove this node from any nodes that reference it
        @nodes.each do |other_node|
          other_node.remove_predecessor(node_id)
          other_node.remove_successor(node_id)
        end
        
        # Remove the node from the workspace
        @nodes.delete(node)
        save_config
        return {true, ""}
      end
      return {false, "Node at index #{index} not found"}
    end
    
    # Removes a node from the workspace by its ID
    #
    # Returns a tuple with success status and error message (if any).
    def remove_node(id : String) : Tuple(Bool, String)
      if node = get_node_by_id(id)
        # Remove this node from any nodes that reference it
        @nodes.each do |other_node|
          other_node.remove_predecessor(id)
          other_node.remove_successor(id)
        end
        
        # Remove the node from the workspace
        @nodes.delete(node)
        save_config
        return {true, ""}
      end
      return {false, "Node with ID '#{id}' not found"}
    end
    
    # Adds a relationship between two nodes (parent → child) by their IDs
    #
    # Returns a tuple with success status and error message (if any).
    def add_relationship(parent_id : String, child_id : String) : Tuple(Bool, String)
      parent = self.get_node_by_id(parent_id)
      child = self.get_node_by_id(child_id)
      
      return {false, "Parent node with ID '#{parent_id}' not found"} unless parent
      return {false, "Child node with ID '#{child_id}' not found"} unless child
      
      return create_dependency(parent, child)
    end
  end