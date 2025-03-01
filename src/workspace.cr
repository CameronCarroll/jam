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
# workspace.add_node(Node.new("Node A", "Description"))
# workspace.save_config
# ```
class Workspace
    # Returns the name of the workspace.
    property name : String
  
    # Returns the list of nodes within the workspace.
    property nodes : Array(Node)
  
    # Initializes a new Workspace with a given name.
    def initialize(@name : String)
      @name = name
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
      node_data_to_save = [] of Hash(String, String | Array(String))
      @nodes.each do |node|
        node_data_to_save << {
            "id" => node.id,
            "name" => node.name,
            "description" => node.description,
            "predecessors" => node.predecessors,
            "successors" => node.successors,
            "requirement_ids" => node.requirement_ids,
            "goal_ids" => node.goal_ids
        }
      end
      jason_content = node_data_to_save.to_json
  
      begin
        File.write(CONFIG_FILE, jason_content)
        puts "Workspace config saved to config file #{CONFIG_FILE}"
      rescue e : File::Error
        puts "Error saving configuration: #{e}"
      end
    end

    # Reads config file, parses the JSON and loads workspace with node data.
    def read_config(config_path) : Nil
      begin
        jason_content = File.read(CONFIG_FILE)
        nodes_data = Array(Hash(String, String | Array(String))).from_json(jason_content)
        raise ConfigError.new("Expected an array of hashes") unless nodes_data.is_a?(Array)
        nodes_data.each do |hash|
          raise ConfigError.new("Expected an array of hashes") unless hash.is_a?(Hash)
          id = hash["id"]
          raise ConfigError.new("Expected a string ID") unless id.is_a?(String)
          name = hash["name"]
          raise ConfigError.new("Expected a string name") unless name.is_a?(String)
          description = hash["description"]
          raise ConfigError.new("Expected a string description") unless description.is_a?(String)
          predecessors = hash["predecessors"]
          raise ConfigError.new("Expected a an array of strings for predecessors") unless predecessors.is_a?(Array(String))
          successors = hash["successors"]
          raise ConfigError.new("Expected a an array of strings for successors") unless successors.is_a?(Array(String))
          requirement_ids = hash["requirement_ids"]
          raise ConfigError.new("Expected a an array of strings for requirement_ids") unless requirement_ids.is_a?(Array(String))
          goal_ids = hash["goal_ids"]
          raise ConfigError.new("Expected a an array of strings for goal_ids") unless goal_ids.is_a?(Array(String))

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
  
    # Retrieves a node from the workspace by its index.
    #
    # Returns the node at the given index, or `nil` if the index is invalid.
    # The index corresponds to the order in which nodes are displayed to the user.
    # See `dump_nodes_for_human`.
    def get_node_by_index(index : Int) : Node?
      return @nodes[index]
    end
  
    # Removes a node from the workspace by its index..
    def remove_node_by_index(index : Int)
      @nodes.delete_at(index)
    end
   
    # Gets a node by ID from our workspace nodes list
    #
    # Returns the node if found, or `nil` if not found.
    def get_node_by_id(id : String) : Node?
      @nodes.find { |node| node.id.strip == id }
    end

    # Create a bidirectional dependency between two nodes
    #
    # Returns `true` on success and `false` on failure.
    def create_dependency(predecessor_id : String, successor_id : String) : Bool
      predecessor = get_node_by_id(predecessor_id)
      successor = get_node_by_id(successor_id)

      return false unless predecessor && successor

      predecessor.add_successor(successor_id)
      successor.add_predecessor(predecessor_id)

      save_config
      return true
    end

    # Remove a bidirectional dependency between two nodes
    #
    # Returns `true` on success and `false` on failure.
    def remove_dependency(predecessor_id : String, successor_id : String) : Bool
      predecessor = get_node_by_id(predecessor_id)
      successor = get_node_by_id(successor_id)
      
      return false unless predecessor && successor
      
      # Remove the bi-directional relationship
      predecessor.remove_successor(successor_id)
      successor.remove_predecessor(predecessor_id)
      
      save_config  # Save changes to config
      return true
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
  end