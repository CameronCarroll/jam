class ProjectCLI
    @workspace : Workspace

    ## Initializes a new `ProjectCLI` instance.
    #
    # Takes a `Workspace` object which is responsible for managing the project data.
    #
    # Args:
    #   workspace (:Workspace): The workspace instance to be used by the CLI.
    def initialize(workspace)
        @workspace = workspace
    end

    ## Creates a new project entry in the workspace.
    #
    # This method guides the user through the process of creating a new project.
    # It prompts for the project name and description via the command line,
    # validates the input, creates a new `Project` object, adds it to the workspace,
    # and then saves the workspace configuration.
    #
    # If the provided project name or description is invalid (e.g., empty name),
    # an error message is displayed, and the operation is aborted.
    #
    # Returns:
    #   Nil
    def new_project_entry
        puts "Creating a new project entry..."
        puts "What is the project name?"
        project_name = gets
        if project_name.is_a?(String)
        if project_name == ""
            puts "Bad name"
            return
        end
        puts "OK now drop in a project description."
        project_description = gets
        if project_description.is_a?(String)
            puts "OK I'm making a new project entry with the name and description provided."
            newproject = Project.new(project_name, project_description)
            @workspace.add_project(newproject)
            @workspace.save_config
        else
            puts "Bad description"
            return
        end
        else
        puts "Bad name"
        end
    end

    ## Edits an existing project entry in the workspace.
    #
    # This method allows the user to modify the name and description of an existing project.
    # It first displays a list of existing projects in the workspace for the user to choose from.
    # The user is then prompted to enter the number corresponding to the project they wish to edit.
    #
    # Upon selecting a valid project number, the current name and description are displayed,
    # and the user is prompted to enter a new name and/or description.
    # Leaving the input blank will keep the current value.
    #
    # After modifications, the workspace configuration is saved.
    #
    # Input validation is performed to ensure a valid project number is entered and
    # to handle potential errors during input processing.
    #
    # Returns:
    #   Nil
    def edit_project_entry
        puts "Editing existing project entry..."
        puts @workspace.dump_projects_for_human # Show projects for reference
        puts "Enter the number of the project you want to edit:"
        project_index_str = gets
        if project_index_str.is_a?(String)
        begin
            project_index = project_index_str.chomp.to_i
            project_to_edit = @workspace.get_project_by_index(project_index)
            if project_to_edit
            puts "You selected project ##{project_index}:"
            puts "Current name: #{project_to_edit.name}"
            puts "Current description: #{project_to_edit.description}"

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

            project_to_edit.name = new_name unless new_name.empty?
            project_to_edit.description = new_description unless new_description.empty?

            @workspace.save_config
            puts "Project ##{project_index} updated."
            else
            puts "Invalid project number."
            end
        rescue e
            puts "Invalid input for project number."
        end
        else
        puts "Invalid input for project number."
        end
    end

    ## Deletes an existing project entry from the workspace.
    #
    # This method facilitates the removal of a project from the workspace.
    # It starts by listing all existing projects to provide context for the user.
    # The user is then prompted to enter the number of the project they wish to delete.
    #
    # After selecting a project number, the method displays the project's name and description
    # and asks for confirmation before proceeding with the deletion.
    # If the user confirms the deletion, the project is removed from the workspace,
    # and the workspace configuration is saved.
    #
    # Input validation is performed to handle invalid project numbers or input formats.
    #
    # Returns:
    #   Nil
    def delete_project_entry
        puts "Deleting existing project entry..."
        puts @workspace.dump_projects_for_human # Show projects for reference
        puts "Enter the number of the project you want to DELETE:"
        project_index_str = gets
        if project_index_str.is_a?(String)
        begin
            project_index = project_index_str.chomp.to_i
            project_to_delete = @workspace.get_project_by_index(project_index)
            if project_to_delete
            puts "You are about to DELETE project ##{project_index}:"
            puts "Name: #{project_to_delete.name}"
            puts "Description: #{project_to_delete.description}"
            puts "Are you sure? (yes/no)"
            if confirmation = gets
                formatted_confirmation = confirmation.chomp.downcase
            else
                puts "Bad confirmation"
                return
            end
            if formatted_confirmation == "yes"
                @workspace.remove_project_by_index(project_index)
                @workspace.save_config
                puts "Project ##{project_index} deleted."
            else
                puts "Deletion cancelled."
            end
            else
            puts "Invalid project number."
            end
        rescue e
            puts "Invalid input for project number."
        end
        else
        puts "Invalid input for project number."
        end
    end

    ## Adds a relationship (dependency) between two projects in the workspace.
    #
    # This method allows users to define dependencies between projects, indicating
    # that one project (successor) depends on another (predecessor).
    # It begins by displaying a list of existing projects for user reference.
    #
    # The method then prompts the user to enter the numbers of two projects:
    # first, the predecessor project, and then the successor project.
    # Input validation ensures that valid project numbers are entered for both.
    #
    # A confirmation step is included to verify the creation of the relationship
    # before it is actually established. If confirmed, the dependency is created
    # within the workspace, and the workspace configuration is saved.
    #
    # The method also prevents creating a relationship between a project and itself.
    #
    # Returns:
    #   Nil
    def add_relationship_between_projects
        puts "Establishing relationship between projects..."
        puts @workspace.dump_projects_for_human # Show projects for reference

        project1 = nil
        project2 = nil
        puts "Enter the number of the first project (predecessor):"
        project_index_str1 = gets
        if project_index_str1.is_a?(String)
            project_index1 = project_index_str1.chomp.to_i
            project1 = @workspace.get_project_by_index(project_index1)
            unless project1
                puts "Invalid project number for the first project."
                return
            end
        else
            puts "Invalid input for the first project number."
            return
        end

        puts "Enter the number of the second project (successor):"
        project_index_str2 = gets
        if project_index_str2.is_a?(String)
            project_index2 = project_index_str2.chomp.to_i
            project2 = @workspace.get_project_by_index(project_index2)
            unless project2
                puts "Invalid project number for the second project."
                return
            end
        else
            puts "Invalid input for the second project number."
            return
        end

        if project_index1 == project_index2
            puts "You cannot select the same project for both predecessor and successor."
            return
        end

        puts "You are about to create a relationship between:"
        puts "Predecessor Project ##{project_index1}: #{project1.name}"
        puts "Successor Project ##{project_index2}: #{project2.name}"
        puts "Are you sure? (yes/no)"
        if confirmation = gets
            formatted_confirmation = confirmation.chomp.downcase
        else
            puts "Bad confirmation"
            return
        end

        if formatted_confirmation == "yes"
            if @workspace.create_dependency(project1.id, project2.id)
                @workspace.save_config
                puts "Relationship established between Project ##{project_index1} and Project ##{project_index2}."
            else
                puts "Failed to create relationship. Please check project IDs and try again."
            end
        else
            puts "Relationship creation cancelled."
        end
    end
end