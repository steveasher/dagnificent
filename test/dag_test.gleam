import dag.{type DAG, apply_update, atomic_update, get_raw_data, new}
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
  EdgeRelation, Node, NodeId, UpsertEdge, UpsertNode,
}

import test_util.{a_node, an_edge}

pub fn main() {
  gleeunit.main()
}

pub fn upsert_node_test() {
  let assert Ok(graph) = apply_update(new(), UpsertNode(a_node(1)))

  let uncertain_graph = get_raw_data(graph)

  // uncertain_graph should contain the node
  should.be_true(uncertain_graph.nodes |> dict.has_key(NodeId("1")))
}

pub fn delete_node_test() {
  let assert Ok(graph) = apply_update(new(), UpsertNode(a_node(1)))
  let assert Ok(graph) = apply_update(graph, DeleteNode(NodeId("1")))

  let uncertain_graph = get_raw_data(graph)

  // uncertain_graph should have no nodes
  should.equal(uncertain_graph.nodes, dict.new())
}

pub fn upsert_edge_test() {
  let assert Ok(dag) = apply_update(new(), UpsertNode(a_node(1)))
  let assert Ok(dag) = apply_update(dag, UpsertNode(a_node(2)))
  let assert Ok(dag) = apply_update(dag, UpsertEdge(an_edge(1, 2)))

  let uncertain_graph = get_raw_data(dag)

  // uncertain_graph should contain the edge
  should.be_true(uncertain_graph.adj_list |> dict.has_key(NodeId("1")))
}

pub fn upsert_edge_would_create_cycle_test() {
  let assert Ok(dag) = apply_update(new(), UpsertNode(a_node(1)))
  let assert Ok(dag) = apply_update(dag, UpsertNode(a_node(2)))
  let assert Ok(dag) = apply_update(dag, UpsertEdge(an_edge(1, 2)))
  let assert Error(message) = apply_update(dag, UpsertEdge(an_edge(2, 1)))

  let uncertain_graph = get_raw_data(dag)

  // uncertain_graph should not contain the edge
  should.equal(message, "Cannot create edge that would create a cycle")
}

pub fn upsert_edge_would_create_self_cycle_test() {
  let assert Ok(dag) = apply_update(new(), UpsertNode(a_node(1)))
  let assert Error(message) = apply_update(dag, UpsertEdge(an_edge(1, 1)))

  let uncertain_graph = get_raw_data(dag)

  // uncertain_graph should not contain the edge
  should.equal(message, "Cannot create edge that would create a cycle")
}

pub fn upsert_edge_would_create_cycle_with_indirect_edge_test() {
  let assert Ok(dag) = apply_update(new(), UpsertNode(a_node(1)))
  let assert Ok(dag) = apply_update(dag, UpsertNode(a_node(2)))
  let assert Ok(dag) = apply_update(dag, UpsertNode(a_node(3)))
  let assert Ok(dag) = apply_update(dag, UpsertEdge(an_edge(1, 2)))
  let assert Ok(dag) = apply_update(dag, UpsertEdge(an_edge(2, 3)))
  let assert Error(message) = apply_update(dag, UpsertEdge(an_edge(3, 1)))

  let uncertain_graph = get_raw_data(dag)

  // uncertain_graph should not contain the edge
  should.equal(message, "Cannot create edge that would create a cycle")
}
