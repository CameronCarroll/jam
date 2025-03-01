require "uuid"

# Represents a single node with a name and description.
#
# A node is some point on a dependency tree - it could be a project, or a requirement, or an end goal.
# At the simplest, a node is an activity with one or more steps, typically with some predecessor and successor node/task.
#
# At the leaf and root nodes of the node's dependency tree lie the 'requirements' and 'goals'. (Which are just named leaf/root nodes.)
#
# The *description* field is intended to hold large multiline strings with the bulk of the contextual data for this task.
#
# `Workspace` provides data access and dependency-tree level methods.
class Node

    # Human-readable name or short description for this task/node
    #
    # Required but may be left as ""
    property name : String

    # Set/return the description of the node.
    #
    # Required but may be left as ""
    property description : String

    # Unique ID for internal references
    #
    # Required but will be assigned automatically at instantiation if it doesn't exist already.
    property id : String

    # Set/return a list of predecessor nodes
    # (ie, nodes that must be completed before this one can start)
    #
    # Optional (defaults to empty array)
    property predecessors : Array(String)

    # Set/return a list of successor nodes
    # (ie, nodes that cannot start until this one is finished)
    #
    # Optional (defaults to empty array)
    property successors : Array(String)

    # Set/return a list of requirement IDs associated with this node/task
    #
    # Optional (defaults to empty array)
    property requirement_ids : Array(String)

    # Set/return a list of goal IDs associated with this node/task
    #
    # Optional (defaults to empty array)
    property goal_ids : Array(String)

    # Initializes a new `Node` with at minimum a name and description.
    #
    # Auto assigns a UUID if not provided.
    #
    # Remaining arguments (predecessors/successors/requirements/goals) are optional.
    def initialize(
        @name : String,
        @description : String,
        @id : String = UUID.random.to_s,
        @predecessors = [] of String,
        @successors = [] of String,
        @requirement_ids = [] of String,
        @goal_ids = [] of String
    )
    end

    # Associates a predecessor to this node based on its *node_id*
    def add_predecessor(node_id : String)
        @predecessors << node_id unless @predecessors.includes?(node_id)
    end

    # Removes a predecessor task from this node's associations based on its *node_id*
    def remove_predecessor(node_id : String)
        @predecessors.delete(node_id)
    end

    # Associates a successor to this node based on its *node_id*
    def add_successor(node_id : String)
        @successors << node_id unless @successors.includes?(node_id)
    end

    # Removes a successor task from this node's associations based on its *node_id*
    def remove_successor(node_id : String)
        @successors.delete(node_id)
    end

    # Associates a requirement ID to this node based on its *node_id*
    #
    # (A requirement is just another node intended to be a leaf node.)
    def add_requirement(node_id : String)
        @requirement_ids << node_id unless @requirement_ids.includes?(node_id)
    end

    # Removes a requirement ID from this node's associations based on its `node_id`
    def remove_requirement(node_id : String)
        @requirement_ids.delete(node_id)
    end

    # Associates a goal to this node based on the goal's *node_id*
    #
    # (A goal is just another node intended to be a a root node.)
    def add_goal(node_id : String)
        @goal_ids << node_id unless @goal_ids.includes?(node_id)
    end

    # Removes a goal from this node's associations based on the goal's *node_id*
    def remove_goal(node_id : String)
        @goal_ids.delete(node_id)
    end
  end