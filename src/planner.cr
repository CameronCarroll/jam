module Planner
    # Find the root projects (projects with no predecessors)
    #
    # @return [Array(Project)] List of root project objects
    def self.get_root_projects(workspace : Workspace) : Array(Project)
        workspace.projects.select { |project| project.predecessors.empty? }
    end

    # Find the leaf projects (projects with no successors)
    #
    # @return [Array(Project)] List of leaf project objects
    def self.get_leaf_projects(workspace : Workspace) : Array(Project)
        workspace.projects.select { |project| project.successors.empty? }
    end

    def self.dump_dependency_graph(workspace : Workspace) : String
    result = String.new
    result += "Project Dependency Graph:\n"
    result += "=========================\n\n"
    
    workspace.projects.each do |project|
        result += "#{project.name} (ID: #{project.id}):\n"
        if project.predecessors.empty?
        result += "  Predecessors: None\n"
        else
        result += "  Predecessors:\n"
        project.predecessors.each do |pred_id|
            if pred = workspace.get_project_by_id(pred_id)
            result += "    - #{pred.name}\n"
            else
            result += "    - Unknown project (#{pred_id})\n"
            end
        end
        end
        
        if project.successors.empty?
        result += "  Successors: None\n"
        else
        result += "  Successors:\n"
        project.successors.each do |succ_id|
            if succ = workspace.get_project_by_id(succ_id)
            result += "    - #{succ.name}\n"
            else
            result += "    - Unknown project (#{succ_id})\n"
            end
        end
        end
        
        result += "\n"
    end
    
    return result
    end

    # Return a topologically sorted list of projects
    # ie, sorted in dependency order
    #
    # @return [Array(Project)] List of projects sorted in dependency order
    def self.get_project_execution_order(workspace : Workspace) : Array(Project)
    # Create a copy of the projects to work with
    remaining_projects = workspace.projects.dup
    result = [] of Project
    
    # Keep processing until all projects are in the result
    while !remaining_projects.empty?
        # Find projects with no unprocessed predecessors
        ready_projects = remaining_projects.select do |project|
        project.predecessors.all? do |pred_id|
            # Either the predecessor is already in the result, or it doesn't exist
            result.any? { |p| p.id == pred_id } || !workspace.get_project_by_id(pred_id)
        end
        end
        
        # If we can't find any ready projects but still have remaining ones,
        # there's a cycle, so we'll add one arbitrarily to break it
        if ready_projects.empty?
        ready_projects = [remaining_projects.first]
        end
        
        # Add ready projects to the result and remove from remaining
        ready_projects.each do |project|
        result << project
        remaining_projects.delete(project)
        end
    end
    
    return result
    end

    # Generates an execution plan with dependency ordering
    #
    # @return [String] Multiline string execution plan (human/LM readable)
    def self.generate_execution_plan(workspace : Workspace) : String
    ordered_projects = get_project_execution_order(workspace)
    
    result = String.new
    result += "Project Execution Plan:\n"
    result += "======================\n\n"
    
    ordered_projects.each_with_index do |project, index|
        result += "Step #{index + 1}: #{project.name}\n"
        result += "  Description: #{project.description}\n"
        
        # List dependencies
        predecessors = workspace.get_predecessors(project.id)
        if !predecessors.empty?
        result += "  Dependencies: #{predecessors.map(&.name).join(", ")}\n"
        end
        
        result += "\n"
    end
    
    return result
    end
end