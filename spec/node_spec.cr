require "./spec_helper"

describe Node do
  # Can we initialize a node object?
  # Can we get and set all of the properties?
  # Are there helper methods we should test the logic for?

  describe "#initialize" do
    it "creates a Node and all attribute fields work" do
      node = Node.new(
        name: "Test node",
        description: "A multiline \n description.",
        id: "7b6dfa4f-ad25-4009-8dda-b75c2993f49e",
        predecessors: ["predecessor1", "predecessor2"],
        successors: ["successor1", "successor2"],
        requirement_ids: ["reqirem 1", "reqirem 2"],
        goal_ids: ["goal1", "goal 2"]
      )
 
      node.name.should eq("Test node")
      node.description.should eq("A multiline \n description.")
      node.id.should eq("7b6dfa4f-ad25-4009-8dda-b75c2993f49e")
      node.predecessors.should eq(["predecessor1", "predecessor2"])
      node.successors.should eq(["successor1", "successor2"])
      node.requirement_ids.should eq(["reqirem 1", "reqirem 2"])
      node.goal_ids.should eq(["goal1", "goal 2"])
    end

    it "creates a Node with defaults if optional arguments not provided" do
      node = Node.new(name: "Simple node", description: "A simple node")

      node.name.should eq("Simple node")
      node.description.should eq("A simple node")
      node.id.should be_a(String)
      node.id.should_not eq("")
      empty_array = [] of String
      node.predecessors.should be_empty
      node.successors.should be_empty
      node.requirement_ids.should be_empty
      node.goal_ids.should be_empty
    end
  end

  describe "helper methods" do
    node = Node.new(name: "Test Node", description: "For testing helper methods")
    node_id1 = "node_1"
    node_id2 = "node_2"

    describe "#add_predecessor" do
      it "adds a predecessor node_id to the predecessors list" do
        node.add_predecessor(node_id1)
        node.predecessors.should eq([node_id1])
      end

      it "does not add duplicate predecessor node_ids" do
        node.add_predecessor(node_id1)
        node.add_predecessor(node_id1)
        node.predecessors.should eq([node_id1])
      end
    end

    describe "#remove_predecessor" do
      it "removes a predecessor node_id from the predecessors list" do
        node.add_predecessor(node_id1)
        node.add_predecessor(node_id2)
        node.remove_predecessor(node_id1)
        node.predecessors.should eq([node_id2])
      end

      it "does not modify the list if the predecessor node_id is not found" do
        node.add_predecessor(node_id1)
        node.remove_predecessor(node_id2)
        node.predecessors.should eq([node_id1])
      end
    end

    describe "#add_successor" do
      it "adds a successor node_id to the successors list" do
        node.add_successor(node_id1)
        node.successors.should eq([node_id1])
      end

      it "does not add duplicate successor node_ids" do
        node.add_successor(node_id1)
        node.add_successor(node_id1)
        node.successors.should eq([node_id1])
      end
    end

    describe "#remove_successor" do
      it "removes a successor node_id from the successors list" do
        node.add_successor(node_id1)
        node.add_successor(node_id2)
        node.remove_successor(node_id1)
        node.successors.should eq([node_id2])
      end

      it "does not modify the list if the successor node_id is not found" do
        node.add_successor(node_id1)
        node.remove_successor(node_id2)
        node.successors.should eq([node_id1])
      end
    end

    describe "#add_requirement" do
      it "adds a requirement node_id to the requirement_ids list" do
        node.add_requirement(node_id1)
        node.requirement_ids.should eq([node_id1])
      end

      it "does not add duplicate requirement node_ids" do
        node.add_requirement(node_id1)
        node.add_requirement(node_id1)
        node.requirement_ids.should eq([node_id1])
      end
    end

    describe "#remove_requirement" do
      it "removes a requirement node_id from the requirement_ids list" do
        node.add_requirement(node_id1)
        node.add_requirement(node_id2)
        node.remove_requirement(node_id1)
        node.requirement_ids.should eq([node_id2])
      end

      it "does not modify the list if the requirement node_id is not found" do
        node.add_requirement(node_id1)
        node.remove_requirement(node_id2)
        node.requirement_ids.should eq([node_id1])
      end
    end

    describe "#add_goal" do
      it "adds a goal node_id to the goal_ids list" do
        node.add_goal(node_id1)
        node.goal_ids.should eq([node_id1])
      end

      it "does not add duplicate goal node_ids" do
        node.add_goal(node_id1)
        node.add_goal(node_id1)
        node.goal_ids.should eq([node_id1])
      end
    end

    describe "#remove_goal" do
      it "removes a goal node_id from the goal_ids list" do
        node.add_goal(node_id1)
        node.add_goal(node_id2)
        node.remove_goal(node_id1)
        node.goal_ids.should eq([node_id2])
      end

      it "does not modify the list if the goal node_id is not found" do
        node.add_goal(node_id1)
        node.remove_goal(node_id2)
        node.goal_ids.should eq([node_id1])
      end
    end
  end
end
