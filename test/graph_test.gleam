import gleam/dict
import gleam/list
import gleeunit
import gleeunit/should
import graph.{
  type Node, EdgeRelation, Node, NodeId, delete_edge, delete_node, get_raw_data,
  new, upsert_edge, upsert_node,
}
import test_util.{a_node, an_edge}

pub fn main() {
  gleeunit.main()
}

pub fn create_node_test() {
  let assert Ok(graph) = upsert_node(new(), a_node(1))
  let raw_data = get_raw_data(graph)

  // raw_data should contain the node
  should.be_true(raw_data.nodes |> dict.has_key(NodeId("1")))
}

pub fn new_graph_has_no_nodes_test() {
  let graph = new()

  let raw_data = get_raw_data(graph)

  // raw_data should have no nodes
  should.equal(raw_data.nodes, dict.new())
}

pub fn atomic_update_of_multiple_nodes_test() {
  let assert Ok(graph) = upsert_node(new(), a_node(1))
  let assert Ok(graph) = upsert_node(graph, a_node(2))

  let raw_data = get_raw_data(graph)

  // raw_data should contain the nodes
  should.be_true(raw_data.nodes |> dict.has_key(NodeId("1")))
  should.be_true(raw_data.nodes |> dict.has_key(NodeId("2")))
}

pub fn update_node_test() {
  let node = Node(id: NodeId("1"), data: "foo")
  let assert Ok(graph) = upsert_node(new(), node)

  let assert Ok(graph) = upsert_node(graph, Node(id: NodeId("1"), data: "bar"))

  let raw_data = get_raw_data(graph)

  let assert Ok(data) = raw_data.nodes |> dict.get(NodeId("1"))
  should.equal(data, "bar")
}

pub fn delete_node_test() {
  let assert Ok(graph) = upsert_node(new(), a_node(1))
  let assert Ok(graph) = graph.delete_node(graph, NodeId("1"))

  let raw_data = get_raw_data(graph)

  // raw_data should have no nodes
  should.equal(raw_data.nodes, dict.new())
}

pub fn delete_non_existent_node_test() {
  let assert Ok(graph) = upsert_node(new(), a_node(1))
  // Deleting a non-existent node should not change the graph
  let assert Ok(graph) = graph.delete_node(graph, NodeId("2"))

  let raw_data = get_raw_data(graph)

  // raw_data should contain the first node
  let assert Ok(data) = raw_data.nodes |> dict.get(NodeId("1"))
  should.equal(data, 1)
}

pub fn delete_node_from_empty_graph_test() {
  let assert Ok(graph) = delete_node(new(), NodeId("1"))
  let raw_data = get_raw_data(graph)

  // raw_data should have no nodes
  should.equal(raw_data.nodes, dict.new())
}

pub fn add_edge_test() {
  let assert Ok(graph) = upsert_node(new(), a_node(1))
  let assert Ok(graph) = upsert_node(graph, a_node(2))
  let assert Ok(graph) = upsert_edge(graph, an_edge(1, 2))

  let raw_data = get_raw_data(graph)

  // raw_data should contain the edge
  should.be_true(raw_data.adj_list |> dict.has_key(NodeId("1")))
  let assert Ok(edges) = raw_data.adj_list |> dict.get(NodeId("1"))
  should.be_true(edges |> list.contains(#(NodeId("2"), EdgeRelation("->"))))
}

pub fn add_edge_to_non_existent_to_node_test() {
  let assert Ok(graph) = upsert_node(new(), a_node(1))
  let assert Error(message) = upsert_edge(graph, an_edge(1, 2))

  should.equal(
    message,
    "Edge would invalidate graph: Edge(EdgeRelation(\"->\"), NodeId(\"1\"), NodeId(\"2\"))",
  )
}

pub fn add_edge_to_non_existent_from_node_test() {
  let assert Ok(graph) = upsert_node(new(), a_node(1))
  let assert Error(message) = upsert_edge(graph, an_edge(3, 2))

  should.equal(
    message,
    "Edge would invalidate graph: Edge(EdgeRelation(\"->\"), NodeId(\"3\"), NodeId(\"2\"))",
  )
}

pub fn delete_edge_test() {
  let assert Ok(graph) = upsert_node(new(), a_node(1))
  let assert Ok(graph) = upsert_node(graph, a_node(2))
  let assert Ok(graph) = upsert_edge(graph, an_edge(1, 2))

  let assert Ok(graph) = delete_edge(graph, an_edge(1, 2))

  let raw_data = get_raw_data(graph)

  // raw_data should not contain the edge
  should.be_false(raw_data.adj_list |> dict.has_key(NodeId("1")))
}

pub fn delete_edge_where_two_edges_share_from_test() {
  let assert Ok(graph) = upsert_node(new(), a_node(1))
  let assert Ok(graph) = upsert_node(graph, a_node(2))
  let assert Ok(graph) = upsert_node(graph, a_node(3))
  let assert Ok(graph) = upsert_edge(graph, an_edge(1, 2))
  let assert Ok(graph) = upsert_edge(graph, an_edge(1, 3))

  let assert Ok(graph) = delete_edge(graph, an_edge(1, 2))

  let raw_data = get_raw_data(graph)

  // raw_data should still contain the other edge: 1 -> 3
  let assert Ok(edges) = raw_data.adj_list |> dict.get(NodeId("1"))
  should.be_true(edges |> list.contains(#(NodeId("3"), EdgeRelation("->"))))
}

pub fn delete_non_existent_edge_test() {
  let assert Ok(graph) = upsert_node(new(), a_node(1))
  let assert Ok(graph) = upsert_node(graph, a_node(2))
  let assert Ok(graph) = upsert_edge(graph, an_edge(1, 2))

  // Deleting a non-existent edge should not change the graph
  let assert Ok(graph) = delete_edge(graph, an_edge(2, 1))

  let raw_data = get_raw_data(graph)

  // raw_data should contain the edge
  should.be_true(raw_data.adj_list |> dict.has_key(NodeId("1")))
  let assert Ok(edges) = raw_data.adj_list |> dict.get(NodeId("1"))
  should.be_true(edges |> list.contains(#(NodeId("2"), EdgeRelation("->"))))
}

pub fn delete_edge_leaving_isolated_node_test() {
  let assert Ok(graph) = upsert_node(new(), a_node(1))
  let assert Ok(graph) = upsert_node(graph, a_node(2))
  let assert Ok(graph) = upsert_edge(graph, an_edge(1, 2))

  let assert Ok(graph) = delete_edge(graph, an_edge(1, 2))

  let raw_data = get_raw_data(graph)

  // The graph should not contain the edge: 1 -> 2
  should.be_false(raw_data.adj_list |> dict.has_key(NodeId("1")))
  should.be_false(raw_data.adj_list |> dict.has_key(NodeId("2")))
}

pub fn delete_edge_from_node_with_no_edges_test() {
  let assert Ok(graph) = upsert_node(new(), a_node(1))

  let assert Ok(graph) = delete_edge(graph, an_edge(1, 2))

  let raw_data = get_raw_data(graph)

  // The graph should not contain any edges
  should.be_false(raw_data.adj_list |> dict.has_key(NodeId("1")))
  should.be_false(raw_data.adj_list |> dict.has_key(NodeId("2")))
}

pub fn delete_edge_creating_disconnected_graph_test() {
  let assert Ok(graph) = upsert_node(new(), a_node(1))
  let assert Ok(graph) = upsert_node(graph, a_node(2))
  let assert Ok(graph) = upsert_node(graph, a_node(3))
  let assert Ok(graph) = upsert_edge(graph, an_edge(1, 2))
  let assert Ok(graph) = upsert_edge(graph, an_edge(2, 3))

  let assert Ok(graph) = delete_edge(graph, an_edge(1, 2))

  let raw_data = get_raw_data(graph)

  // The graph should still contain the edge: 2 -> 3
  let assert Ok(edges) = raw_data.adj_list |> dict.get(NodeId("2"))
  should.be_true(edges |> list.contains(#(NodeId("3"), EdgeRelation("->"))))
}

pub fn delete_node_with_downstream_edges_test() {
  let assert Ok(graph) = upsert_node(new(), a_node(1))
  let assert Ok(graph) = upsert_node(graph, a_node(2))
  let assert Ok(graph) = upsert_node(graph, a_node(3))
  let assert Ok(graph) = upsert_edge(graph, an_edge(1, 2))
  let assert Ok(graph) = upsert_edge(graph, an_edge(2, 3))

  let assert Ok(graph) = delete_node(graph, NodeId("2"))

  let raw_data = get_raw_data(graph)

  // The graph should not contain the node
  should.be_false(raw_data.nodes |> dict.has_key(NodeId("2")))

  // The graph should not contain the edge: 2 -> 3
  should.be_false(raw_data.adj_list |> dict.has_key(NodeId("2")))
}
