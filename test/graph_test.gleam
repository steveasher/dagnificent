import gleam/dict
import gleam/int
import gleam/io
import gleam/list
import gleam/result
import gleam/string
import gleeunit
import gleeunit/should
import graph.{
  type Edge, type Node, type WriteOperation, DeleteEdge, DeleteNode, Edge,
  EdgeRelation, Node, NodeId, UpsertEdge, UpsertNode, apply_update,
  atomic_update, get_raw_data, new,
}

pub fn main() {
  gleeunit.main()
}

fn a_node(data: Int) -> Node(Int) {
  Node(id: NodeId(int.to_string(data)), data: data)
}

fn an_edge(from: Int, to: Int) -> Edge(String) {
  Edge(
    relation: graph.EdgeRelation("->"),
    from: NodeId(int.to_string(from)),
    to: NodeId(int.to_string(to)),
  )
}

pub fn create_node_test() {
  let assert Ok(graph) = apply_update(new(), UpsertNode(a_node(1)))

  let uncertain_graph = get_raw_data(graph)

  // uncertain_graph should contain the node
  should.be_true(uncertain_graph.nodes |> dict.has_key(NodeId("1")))
}

pub fn new_graph_has_no_nodes_test() {
  let graph = new()

  let uncertain_graph = get_raw_data(graph)

  // uncertain_graph should have no nodes
  should.equal(uncertain_graph.nodes, dict.new())
}

pub fn atomic_update_of_multiple_nodes_test() {
  let assert Ok(graph) =
    atomic_update(new(), [UpsertNode(a_node(1)), UpsertNode(a_node(2))])

  let uncertain_graph = get_raw_data(graph)

  // uncertain_graph should contain the nodes
  should.be_true(uncertain_graph.nodes |> dict.has_key(NodeId("1")))
  should.be_true(uncertain_graph.nodes |> dict.has_key(NodeId("2")))
}

pub fn update_node_test() {
  let node = Node(id: NodeId("1"), data: "foo")
  let assert Ok(graph) = apply_update(new(), UpsertNode(node))

  let assert Ok(graph) =
    apply_update(graph, UpsertNode(Node(id: NodeId("1"), data: "bar")))

  let uncertain_graph = get_raw_data(graph)

  let assert Ok(data) = uncertain_graph.nodes |> dict.get(NodeId("1"))
  should.equal(data, "bar")
}

pub fn delete_node_test() {
  let assert Ok(graph) = apply_update(new(), UpsertNode(a_node(1)))

  let assert Ok(graph) = apply_update(graph, DeleteNode(NodeId("1")))

  let uncertain_graph = get_raw_data(graph)

  // uncertain_graph should have no nodes
  should.equal(uncertain_graph.nodes, dict.new())
}

pub fn delete_non_existent_node_test() {
  let assert Ok(graph) = apply_update(new(), UpsertNode(a_node(1)))

  // Deleting a non-existent node should not change the graph
  let assert Ok(graph) = apply_update(graph, DeleteNode(NodeId("2")))

  let uncertain_graph = get_raw_data(graph)

  // uncertain_graph should contain the first node
  let assert Ok(data) = uncertain_graph.nodes |> dict.get(NodeId("1"))
  should.equal(data, 1)
}

pub fn delete_node_from_empty_graph_test() {
  let assert Ok(graph) = apply_update(new(), DeleteNode(NodeId("1")))

  let uncertain_graph = get_raw_data(graph)

  // uncertain_graph should have no nodes
  should.equal(uncertain_graph.nodes, dict.new())
}

pub fn add_edge_test() {
  let assert Ok(graph) =
    new()
    |> atomic_update([
      UpsertNode(a_node(1)),
      UpsertNode(a_node(2)),
      UpsertEdge(an_edge(1, 2)),
    ])

  let uncertain_graph = get_raw_data(graph)

  // uncertain_graph should contain the edge
  should.be_true(uncertain_graph.adj_list |> dict.has_key(NodeId("1")))
  let assert Ok(edges) = uncertain_graph.adj_list |> dict.get(NodeId("1"))
  should.be_true(edges |> list.contains(#(NodeId("2"), EdgeRelation("->"))))
}

pub fn add_edge_to_non_existent_to_node_test() {
  let assert Ok(graph) = apply_update(new(), UpsertNode(a_node(1)))
  let assert Error(message) = apply_update(graph, UpsertEdge(an_edge(1, 2)))

  should.equal(
    message,
    "Edge would invalidate graph: Edge(EdgeRelation(\"->\"), NodeId(\"1\"), NodeId(\"2\"))",
  )
}

pub fn add_edge_to_non_existent_from_node_test() {
  let assert Ok(graph) = apply_update(new(), UpsertNode(a_node(1)))
  let assert Error(message) = apply_update(graph, UpsertEdge(an_edge(3, 2)))

  should.equal(
    message,
    "Edge would invalidate graph: Edge(EdgeRelation(\"->\"), NodeId(\"3\"), NodeId(\"2\"))",
  )
}

pub fn delete_edge_test() {
  let assert Ok(graph) =
    new()
    |> atomic_update([
      UpsertNode(a_node(1)),
      UpsertNode(a_node(2)),
      UpsertEdge(an_edge(1, 2)),
    ])

  let assert Ok(graph) = apply_update(graph, DeleteEdge(an_edge(1, 2)))

  let uncertain_graph = get_raw_data(graph)

  // uncertain_graph should not contain the edge
  should.be_false(uncertain_graph.adj_list |> dict.has_key(NodeId("1")))
}

pub fn delete_edge_where_two_edges_share_from_test() {
  let assert Ok(graph) =
    new()
    |> atomic_update([
      UpsertNode(a_node(1)),
      UpsertNode(a_node(2)),
      UpsertNode(a_node(3)),
      UpsertEdge(an_edge(1, 2)),
      UpsertEdge(an_edge(1, 3)),
    ])

  let assert Ok(graph) = apply_update(graph, DeleteEdge(an_edge(1, 2)))

  let uncertain_graph = get_raw_data(graph)

  // uncertain_graph should still contain the other edge: 1 -> 3 
  let assert Ok(edges) = uncertain_graph.adj_list |> dict.get(NodeId("1"))
  should.be_true(edges |> list.contains(#(NodeId("3"), EdgeRelation("->"))))
}

pub fn delete_non_existent_edge_test() {
  let assert Ok(graph) =
    new()
    |> atomic_update([
      UpsertNode(a_node(1)),
      UpsertNode(a_node(2)),
      UpsertEdge(an_edge(1, 2)),
    ])

  // Deleting a non-existent edge should not change the graph
  let assert Ok(graph) = apply_update(graph, DeleteEdge(an_edge(2, 1)))

  let uncertain_graph = get_raw_data(graph)

  // uncertain_graph should contain the edge
  should.be_true(uncertain_graph.adj_list |> dict.has_key(NodeId("1")))
  let assert Ok(edges) = uncertain_graph.adj_list |> dict.get(NodeId("1"))
  should.be_true(edges |> list.contains(#(NodeId("2"), EdgeRelation("->"))))
}

pub fn delete_edge_leaving_isolated_node_test() {
  let assert Ok(graph) =
    new()
    |> atomic_update([
      UpsertNode(a_node(1)),
      UpsertNode(a_node(2)),
      UpsertEdge(an_edge(1, 2)),
    ])

  let assert Ok(graph) = apply_update(graph, DeleteEdge(an_edge(1, 2)))

  let uncertain_graph = get_raw_data(graph)

  // The graph should not contain the edge: 1 -> 2
  should.be_false(uncertain_graph.adj_list |> dict.has_key(NodeId("1")))
  should.be_false(uncertain_graph.adj_list |> dict.has_key(NodeId("2")))
}

pub fn delete_edge_from_node_with_no_edges_test() {
  let assert Ok(graph) =
    new()
    |> atomic_update([UpsertNode(a_node(1)), UpsertNode(a_node(2))])

  let assert Ok(graph) = apply_update(graph, DeleteEdge(an_edge(1, 2)))

  let uncertain_graph = get_raw_data(graph)

  // The graph should not contain any edges
  should.be_false(uncertain_graph.adj_list |> dict.has_key(NodeId("1")))
  should.be_false(uncertain_graph.adj_list |> dict.has_key(NodeId("2")))
}

pub fn delete_edge_creating_disconnected_graph_test() {
  let assert Ok(graph) =
    new()
    |> atomic_update([
      UpsertNode(a_node(1)),
      UpsertNode(a_node(2)),
      UpsertNode(a_node(3)),
      UpsertEdge(an_edge(1, 2)),
      UpsertEdge(an_edge(2, 3)),
    ])

  let assert Ok(graph) = apply_update(graph, DeleteEdge(an_edge(1, 2)))

  let uncertain_graph = get_raw_data(graph)

  // The graph should still contain the edge: 2 -> 3
  let assert Ok(edges) = uncertain_graph.adj_list |> dict.get(NodeId("2"))
  should.be_true(edges |> list.contains(#(NodeId("3"), EdgeRelation("->"))))
}

pub fn delete_node_with_downstream_edges_test() {
  let assert Ok(graph) =
    new()
    |> atomic_update([
      UpsertNode(a_node(1)),
      UpsertNode(a_node(2)),
      UpsertNode(a_node(3)),
      UpsertEdge(an_edge(1, 2)),
      UpsertEdge(an_edge(2, 3)),
    ])

  let assert Ok(graph) = apply_update(graph, DeleteNode(NodeId("2")))

  let uncertain_graph = get_raw_data(graph)

  // The graph should not contain the node
  should.be_false(uncertain_graph.nodes |> dict.has_key(NodeId("2")))

  // The graph should not contain the edge: 2 -> 3
  should.be_false(uncertain_graph.adj_list |> dict.has_key(NodeId("2")))
}
