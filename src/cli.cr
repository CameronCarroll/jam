class ProjectCLI
  @workspace : Workspace

  # Initializes a new `ProjectCLI` instance.
  #
  # Takes a `Workspace` object which is responsible for managing the node data.
  #
  # Args:
  #   workspace (:Workspace): The workspace instance to be used by the CLI.
  def initialize(workspace)
    @workspace = workspace
  end

  # Creates a new node entry in the workspace.
  #
  # This method guides the user through the process of creating a new node.
  # It prompts for the node name and description via the command line,
  # validates the input, creates a new `Project` object, adds it to the workspace,
  # and then saves the workspace configuration.
  #
  # If the provided node name or description is invalid (e.g., empty name),
  # an error message is displayed, and the operation is aborted.
  #
  # Returns:
  #   Nil
  def new_node_entry
    puts "Creating a new node entry..."
    puts "What is the node name?"
    node_name = gets
    if node_name.is_a?(String)
      if node_name == ""
        puts "Bad name"
        return
      end
      puts "OK now drop in a node description."
      node_description = gets
      if node_description.is_a?(String)
        puts "OK I'm making a new node entry with the name and description provided."
        newnode = Node.new(node_name, node_description)
        @workspace.add_node(newnode)
        @workspace.save_config
      else
        puts "Bad description"
        return
      end
    else
      puts "Bad name"
    end
  end

  # Edits an existing node entry in the workspace.
  #
  # This method allows the user to modify the name and description of an existing node.
  # It first displays a list of existing nodes in the workspace for the user to choose from.
  # The user is then prompted to enter the number corresponding to the node they wish to edit.
  #
  # Upon selecting a valid node number, the current name and description are displayed,
  # and the user is prompted to enter a new name and/or description.
  # Leaving the input blank will keep the current value.
  #
  # After modifications, the workspace configuration is saved.
  #
  # Input validation is performed to ensure a valid node number is entered and
  # to handle potential errors during input processing.
  #
  # Returns:
  #   Nil
  def edit_node_entry
    puts "Editing existing node entry..."
    puts @workspace.dump_nodes_for_human # Show nodes for reference
    puts "Enter the number of the node you want to edit:"
    node_index_str = gets
    if node_index_str.is_a?(String)
      begin
        node_index = node_index_str.chomp.to_i
        node_to_edit = @workspace.get_node_by_index(node_index)
        if node_to_edit
          puts "You selected node ##{node_index}:"
          puts "Current name: #{node_to_edit.name}"
          puts "Current description: #{node_to_edit.description}"

          puts "Enter new name (or leave blank to keep current):"
          if new_name = gets
            new_name = new_name.chomp
          else
            puts "Bad name"
            return
          end
          puts "Enter new description (or leave blank to keep current):"
          if new_description = gets
            new_description = new_description.chomp
          else
            puts "Bad description"
            return
          end

          node_to_edit.name = new_name unless new_name.empty?
          node_to_edit.description = new_description unless new_description.empty?

          @workspace.save_config
          puts "Node ##{node_index} updated."
        else
          puts "Invalid node number."
        end
      rescue e
        puts "Invalid input for node number."
      end
    else
      puts "Invalid input for node number."
    end
  end

  # Deletes an existing node entry from the workspace.
  #
  # This method facilitates the removal of a node from the workspace.
  # It starts by listing all existing nodes to provide context for the user.
  # The user is then prompted to enter the number of the node they wish to delete.
  #
  # After selecting a node number, the method displays the node's name and description
  # and asks for confirmation before proceeding with the deletion.
  # If the user confirms the deletion, the node is removed from the workspace,
  # and the workspace configuration is saved.
  #
  # Input validation is performed to handle invalid node numbers or input formats.
  #
  # Returns:
  #   Nil
  def delete_node_entry
    puts "Deleting existing node entry..."
    puts @workspace.dump_nodes_for_human # Show nodes for reference
    puts "Enter the number of the node you want to DELETE:"
    node_index_str = gets
    if node_index_str.is_a?(String)
      begin
        node_index = node_index_str.chomp.to_i
        node_to_delete = @workspace.get_node_by_index(node_index)
        if node_to_delete
          puts "You are about to DELETE node ##{node_index}:"
          puts "Name: #{node_to_delete.name}"
          puts "Description: #{node_to_delete.description}"
          puts "Are you sure? (yes/no)"
          if confirmation = gets
            formatted_confirmation = confirmation.chomp.downcase
          else
            puts "Bad confirmation"
            return
          end
          if formatted_confirmation == "yes"
            @workspace.remove_node_by_index(node_index)
            @workspace.save_config
            puts "Node ##{node_index} deleted."
          else
            puts "Deletion cancelled."
          end
        else
          puts "Invalid node number."
        end
      rescue e
        puts "Invalid input for node number."
      end
    else
      puts "Invalid input for node number."
    end
  end

  # Adds a relationship (dependency) between two nodes in the workspace.
  #
  # This method allows users to define dependencies between nodes, indicating
  # that one node (successor) depends on another (predecessor).
  # It begins by displaying a list of existing nodes for user reference.
  #
  # The method then prompts the user to enter the numbers of two nodes:
  # first, the predecessor node, and then the successor node.
  # Input validation ensures that valid node numbers are entered for both.
  #
  # A confirmation step is included to verify the creation of the relationship
  # before it is actually established. If confirmed, the dependency is created
  # within the workspace, and the workspace configuration is saved.
  #
  # The method also prevents creating a relationship between a node and itself.
  #
  # Returns:
  #   Nil
  def add_relationship_between_nodes
    puts "Establishing relationship between nodes..."
    puts @workspace.dump_nodes_for_human # Show nodes for reference

    node1 = nil
    node2 = nil
    puts "Enter the number of the first node (predecessor):"
    node_index_str1 = gets
    if node_index_str1.is_a?(String)
      node_index1 = node_index_str1.chomp.to_i
      node1 = @workspace.get_node_by_index(node_index1)
      unless node1
        puts "Invalid node number for the first node."
        return
      end
    else
      puts "Invalid input for the first node number."
      return
    end

    puts "Enter the number of the second node (successor):"
    node_index_str2 = gets
    if node_index_str2.is_a?(String)
      node_index2 = node_index_str2.chomp.to_i
      node2 = @workspace.get_node_by_index(node_index2)
      unless node2
        puts "Invalid node number for the second node."
        return
      end
    else
      puts "Invalid input for the second node number."
      return
    end

    if node_index1 == node_index2
      puts "You cannot select the same node for both predecessor and successor."
      return
    end

    puts "You are about to create a relationship between:"
    puts "Predecessor Node ##{node_index1}: #{node1.name}"
    puts "Successor Node ##{node_index2}: #{node2.name}"
    puts "Are you sure? (yes/no)"
    if confirmation = gets
      formatted_confirmation = confirmation.chomp.downcase
    else
      puts "Bad confirmation"
      return
    end

    if formatted_confirmation == "yes"
      success, message = @workspace.create_dependency(node1, node2)
      if success
        puts "Relationship established between Node ##{node_index1} and Node ##{node_index2}."
      else
        puts "Failed to create relationship: #{message}"
      end
    else
      puts "Relationship creation cancelled."
    end
  end
end
