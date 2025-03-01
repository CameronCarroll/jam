module Planner
    # Find the root nodes (nodes with no predecessors)
    #
    # Requires passing in the workspace object for data/method access.
    #
    # Returns a list of root node objects in the workspace.
    def self.get_root_nodes(workspace : Workspace) : Array(Node)
        workspace.nodes.select { |node| node.predecessors.empty? }
    end

    # Find the leaf nodes (nodes with no successors)
    #
    # Requires passing in the workspace object for data/method access.
    #
    # Returns a list of leaf node objects in the workspace.
    def self.get_leaf_nodes(workspace : Workspace) : Array(Node)
        workspace.nodes.select { |node| node.successors.empty? }
    end

    # Prints out a list of nodes along with their predecessor and successors.
    # It's not a real dependency graph
    #
    # Requires passing in the workspace object for data/method access.
    # 
    # Returns a multiline string of the dependency graph report
    def self.dump_dependency_graph(workspace : Workspace) : String
    result = String.new
    result += "Node Dependency Graph:\n"
    result += "=========================\n\n"
    
    workspace.nodes.each do |node|
        result += "#{node.name} (ID: #{node.id}):\n"
        if node.predecessors.empty?
        result += "  Predecessors: None\n"
        else
        result += "  Predecessors:\n"
        node.predecessors.each do |pred_id|
            if pred = workspace.get_node_by_id(pred_id)
            result += "    - #{pred.name}\n"
            else
            result += "    - Unknown node (#{pred_id})\n"
            end
        end
        end
        
        if node.successors.empty?
        result += "  Successors: None\n"
        else
        result += "  Successors:\n"
        node.successors.each do |succ_id|
            if succ = workspace.get_node_by_id(succ_id)
            result += "    - #{succ.name}\n"
            else
            result += "    - Unknown node (#{succ_id})\n"
            end
        end
        end
        
        result += "\n"
    end
    
    return result
    end

    # Return a topologically sorted list of nodes
    # ie, sorted in dependency order
    #
    # Requires passing in the workspace object for data/method access.
    # 
    # Returns an array of `Node` sorted in execution order.
    def self.get_node_execution_order(workspace : Workspace) : Array(Node)
    # Create a copy of the nodes to work with
    remaining_nodes = workspace.nodes.dup
    result = [] of Node
    
    # Keep processing until all nodes are in the result
    while !remaining_nodes.empty?
        # Find nodes with no unprocessed predecessors
        ready_nodes = remaining_nodes.select do |node|
        node.predecessors.all? do |pred_id|
            # Either the predecessor is already in the result, or it doesn't exist
            result.any? { |p| p.id == pred_id } || !workspace.get_node_by_id(pred_id)
        end
        end
        
        # If we can't find any ready nodes but still have remaining ones,
        # there's a cycle, so we'll add one arbitrarily to break it
        if ready_nodes.empty?
        ready_nodes = [remaining_nodes.first]
        end
        
        # Add ready nodes to the result and remove from remaining
        ready_nodes.each do |node|
        result << node
        remaining_nodes.delete(node)
        end
    end
    
    return result
    end

    # Generates an execution plan with dependency ordering
    #
    # Requires passing in the workspace object for data/method access.
    # 
    # Returns a multiline string execution plan (human/LM readable)
    def self.generate_execution_plan(workspace : Workspace) : String
    ordered_nodes = get_node_execution_order(workspace)
    
    result = String.new
    result += "Node Execution Plan:\n"
    result += "======================\n\n"
    
    ordered_nodes.each_with_index do |node, index|
        result += "Step #{index + 1}: #{node.name}\n"
        result += "  Description: #{node.description}\n"
        
        # List dependencies
        predecessors = workspace.get_predecessors(node.id)
        if !predecessors.empty?
        result += "  Dependencies: #{predecessors.map(&.name).join(", ")}\n"
        end
        
        result += "\n"
    end
    
    return result
    end
end