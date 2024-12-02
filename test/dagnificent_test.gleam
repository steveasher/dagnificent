import dagnificent.{get_raw_data, new} as dag
import gleam/dict
import gleeunit
import gleeunit/should
import graph.{NodeId}

import test_util.{a_node, an_edge}

pub fn main() {
  gleeunit.main()
}

pub fn upsert_node_test() {
  let assert Ok(dag) = dag.upsert_node(new(), a_node(1))
  let raw_data = get_raw_data(dag)

  // raw_data should contain the node
  should.be_true(raw_data.nodes |> dict.has_key(NodeId("1")))
}

pub fn delete_node_test() {
  let assert Ok(dag) = dag.upsert_node(new(), a_node(1))
  let assert Ok(dag) = dag.delete_node(dag, NodeId("1"))

  let raw_data = get_raw_data(dag)

  // raw_data should have no nodes
  should.equal(raw_data.nodes, dict.new())
}

pub fn upsert_edge_test() {
  let assert Ok(dag) = dag.upsert_node(new(), a_node(1))
  let assert Ok(dag) = dag.upsert_node(dag, a_node(2))
  let assert Ok(dag) = dag.upsert_edge(dag, an_edge(1, 2))

  let raw_data = get_raw_data(dag)

  // raw_data should contain the edge
  should.be_true(raw_data.adj_list |> dict.has_key(NodeId("1")))
}

pub fn upsert_edge_would_create_cycle_test() {
  let assert Ok(dag) = dag.upsert_node(new(), a_node(1))
  let assert Ok(dag) = dag.upsert_node(dag, a_node(2))
  let assert Ok(dag) = dag.upsert_edge(dag, an_edge(1, 2))
  let assert Error(message) = dag.upsert_edge(dag, an_edge(2, 1))

  should.equal(message, "Cannot create edge that would create a cycle")
}

pub fn upsert_edge_would_create_self_cycle_test() {
  let assert Ok(dag) = dag.upsert_node(new(), a_node(1))
  let assert Error(message) = dag.upsert_edge(dag, an_edge(1, 1))

  should.equal(message, "Cannot create edge that would create a cycle")
}

pub fn upsert_edge_would_create_cycle_with_indirect_edge_test() {
  let assert Ok(dag) = dag.upsert_node(new(), a_node(1))
  let assert Ok(dag) = dag.upsert_node(dag, a_node(2))
  let assert Ok(dag) = dag.upsert_node(dag, a_node(3))
  let assert Ok(dag) = dag.upsert_edge(dag, an_edge(1, 2))
  let assert Ok(dag) = dag.upsert_edge(dag, an_edge(2, 3))
  let assert Error(message) = dag.upsert_edge(dag, an_edge(3, 1))

  should.equal(message, "Cannot create edge that would create a cycle")
}

pub fn delete_edge_test() {
  let assert Ok(dag) = dag.upsert_node(new(), a_node(1))
  let assert Ok(dag) = dag.upsert_node(dag, a_node(2))
  let assert Ok(dag) = dag.upsert_edge(dag, an_edge(1, 2))
  let assert Ok(dag) = dag.delete_edge(dag, an_edge(1, 2))

  let raw_data = get_raw_data(dag)

  // raw_data should not contain the edge
  should.be_false(raw_data.adj_list |> dict.has_key(NodeId("1")))
}
