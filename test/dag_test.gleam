import dag.{
  type Edge, type EdgeRelation, type Graph, type Node, type NodeId, type Session,
  Edge, EdgeRelation, Node, NodeId, add_edge, add_node, create_session,
  empty_session, get_dag, has_cycle, promote_to_dag, promote_to_graph,
  update_node_data,
}
import gleam/int
import gleam/list
import gleeunit/should
import qcheck
import qcheck_gleeunit_utils/run

pub fn main() {
  run.run_gleeunit()
}

// Just for example of qcheck usage
pub fn small_positive_or_zero_int__test() {
  use n <- qcheck.given(qcheck.small_positive_or_zero_int())
  n + 1 == 1 + n
}

pub fn small_positive_int__test() {
  use n <- qcheck.given(qcheck.small_strictly_positive_int())
  n != 0
}

fn nodes_for_range(from: Int, to: Int) -> List(Node(Int)) {
  list.range(from, to)
  |> list.map(fn(i) { Node(id: NodeId(int.to_string(i)), data: i) })
}

fn edges_from_tuples(tuples: List(#(Int, Int))) -> List(Edge(String)) {
  tuples
  |> list.map(fn(t) {
    let #(from, to) = t
    Edge(
      EdgeRelation("->"),
      from: NodeId(int.to_string(from)),
      to: NodeId(int.to_string(to)),
    )
  })
}

fn session_from(nodes: List(Node(a)), edges: List(Edge(b))) -> Session(a, b) {
  let assert Ok(graph) = promote_to_graph(nodes, edges)
  let assert Ok(dag) = promote_to_dag(graph)
  create_session(dag)
}

pub fn add_node_test() {
  let node = Node(id: NodeId("1"), data: 1)
  let update_handler = fn(_) { Ok(Nil) }
  let expected_session = session_from([node], [])

  let assert Ok(session) =
    empty_session()
    |> add_node(node, update_handler)

  should.equal(session, expected_session)
}

pub fn add_node_with_failing_update_handler_test() {
  let node = Node(id: NodeId("1"), data: 1)
  let update_handler = fn(_) { Error("failed!") }

  let assert Error(message) =
    empty_session()
    |> add_node(node, update_handler)

  should.equal(message, "failed!")
}

pub fn add_node_with_node_id_already_exists_test() {
  let node = Node(id: NodeId("1"), data: 1)
  let update_handler = fn(_) { Ok(Nil) }

  let assert Ok(session) =
    empty_session()
    |> add_node(node, update_handler)

  let assert Error(message) =
    session
    |> add_node(node, update_handler)

  should.equal(message, "Node already exists: 1")
}

pub fn add_edge_test() {
  let edge = Edge(EdgeRelation("->"), from: NodeId("1"), to: NodeId("2"))
  let expected_session = session_from(nodes_for_range(1, 2), [edge])

  let assert Ok(session) =
    session_from(nodes_for_range(1, 2), [])
    |> add_edge(edge, fn(_) { Ok(Nil) })

  should.equal(session, expected_session)
}

pub fn add_edge_with_failing_update_handler_test() {
  let edge = Edge(EdgeRelation("->"), from: NodeId("1"), to: NodeId("2"))

  let assert Error(message) =
    session_from(nodes_for_range(1, 2), [])
    |> add_edge(edge, fn(_) { Error("failed!") })

  should.equal(message, "failed!")
}

pub fn add_edge_with_missing_to_node_test() {
  let edge = Edge(EdgeRelation("->"), from: NodeId("1"), to: NodeId("3"))

  let assert Error(message) =
    session_from(nodes_for_range(1, 2), [])
    |> add_edge(edge, fn(_) { Ok(Nil) })

  should.equal(message, "To node does not exist: NodeId(\"3\")")
}

pub fn add_edge_with_missing_from_node_test() {
  let edge = Edge(EdgeRelation("->"), from: NodeId("4"), to: NodeId("2"))

  let assert Error(message) =
    session_from(nodes_for_range(1, 2), [])
    |> add_edge(edge, fn(_) { Ok(Nil) })

  should.equal(message, "From node does not exist: NodeId(\"4\")")
}

pub fn update_node_data_test() {
  let session = session_from(nodes_for_range(1, 1), [])
  let assert Ok(updated_session) = update_node_data(session, NodeId("1"), 9)

  let expected_session = session_from([Node(id: NodeId("1"), data: 9)], [])

  should.equal(updated_session, expected_session)
}

pub fn has_cycle_empty_graph_test() {
  let assert Ok(graph) = promote_to_graph([], [])
  let assert Ok(dag) = promote_to_dag(graph)
  should.equal(has_cycle(graph), False)
}

pub fn has_cycle_single_node_test() {
  let node = Node(id: NodeId("1"), data: 1)
  let assert Ok(graph) = promote_to_graph([node], [])
  should.equal(has_cycle(graph), False)
}

pub fn has_cycle_multiple_nodes_no_edges_test() {
  let nodes = nodes_for_range(1, 2)
  let assert Ok(graph) = promote_to_graph(nodes, [])
  should.equal(has_cycle(graph), False)
}

pub fn has_cycle_simple_acyclic_graph_test() {
  let nodes = nodes_for_range(1, 2)
  let edge = Edge(EdgeRelation("->"), from: NodeId("1"), to: NodeId("2"))
  let assert Ok(graph) = promote_to_graph(nodes, [edge])
  should.equal(has_cycle(graph), False)
}

pub fn has_cycle_simple_cyclic_graph_test() {
  let nodes = nodes_for_range(1, 2)
  let edges = edges_from_tuples([#(1, 2), #(2, 1)])
  let assert Ok(graph) = promote_to_graph(nodes, edges)
  should.equal(has_cycle(graph), True)
}

pub fn has_cycle_small_acyclic_graph_test() {
  let nodes = nodes_for_range(1, 3)
  let edges = edges_from_tuples([#(1, 2), #(2, 3)])
  let assert Ok(graph) = promote_to_graph(nodes, edges)
  should.equal(has_cycle(graph), False)
}

pub fn has_cycle_complex_cyclic_graph_test() {
  let nodes = nodes_for_range(1, 3)
  let edges = edges_from_tuples([#(1, 2), #(2, 3), #(3, 1)])
  let assert Ok(graph) = promote_to_graph(nodes, edges)
  should.equal(has_cycle(graph), True)
}

pub fn has_cycle_with_self_loop_test() {
  let node1 = Node(id: NodeId("1"), data: 1)
  let edge = Edge(EdgeRelation("->"), from: NodeId("1"), to: NodeId("1"))
  let assert Ok(graph) = promote_to_graph([node1], [edge])
  should.equal(has_cycle(graph), True)
}

pub fn has_cycle_with_disconnected_node_test() {
  let nodes = nodes_for_range(1, 3)
  let edge = Edge(EdgeRelation("->"), from: NodeId("1"), to: NodeId("2"))
  let assert Ok(graph) = promote_to_graph(nodes, [edge])
  should.equal(has_cycle(graph), False)
}

pub fn has_cycle_with_disconnected_node_with_cycle_test() {
  let nodes = nodes_for_range(1, 3)
  let edge = Edge(EdgeRelation("->"), from: NodeId("1"), to: NodeId("2"))
  let cyclic_edge = Edge(EdgeRelation("->"), from: NodeId("3"), to: NodeId("3"))
  let assert Ok(graph) = promote_to_graph(nodes, [edge, cyclic_edge])
  should.equal(has_cycle(graph), True)
}

pub fn has_cycle_in_subgraph_test() {
  let nodes = nodes_for_range(1, 3)
  let edges = edges_from_tuples([#(1, 2), #(2, 3), #(3, 2)])
  let assert Ok(graph) = promote_to_graph(nodes, edges)
  should.equal(has_cycle(graph), True)
}

// This is to ensure tail recursion optimization is happening
pub fn has_cycle_with_super_long_acyclic_graph_test() {
  let nodes = nodes_for_range(1, 1000)
  let edges =
    list.range(1, 999)
    |> list.map(fn(i) {
      Edge(
        EdgeRelation("->"),
        from: NodeId(int.to_string(i)),
        to: NodeId(int.to_string(i + 1)),
      )
    })

  let assert Ok(graph) = promote_to_graph(nodes, edges)
  should.equal(has_cycle(graph), False)
}

pub fn has_cycle_with_super_long_cyclic_graph_test() {
  let nodes = nodes_for_range(1, 1000)
  let edges =
    list.range(1, 999)
    |> list.map(fn(i) {
      Edge(
        EdgeRelation("->"),
        from: NodeId(int.to_string(i)),
        to: NodeId(int.to_string(i + 1)),
      )
    })
  let edges =
    list.append(edges, [
      Edge(EdgeRelation("->"), from: NodeId("1000"), to: NodeId("1")),
    ])

  let assert Ok(graph) = promote_to_graph(nodes, edges)
  should.equal(has_cycle(graph), True)
}

pub fn promote_to_dag_test() {
  let nodes = nodes_for_range(1, 3)
  let edges = edges_from_tuples([#(1, 2), #(2, 3)])
  let assert Ok(graph) = promote_to_graph(nodes, edges)
  let assert Ok(_) = promote_to_dag(graph)
}

pub fn promote_to_dag_with_cycle_test() {
  let nodes = nodes_for_range(1, 3)
  let edges = edges_from_tuples([#(1, 2), #(2, 3), #(3, 1)])
  let assert Ok(graph) = promote_to_graph(nodes, edges)
  let assert Error(message) = promote_to_dag(graph)

  should.equal(message, "Graph has a cycle.")
}

pub fn promote_to_graph_test() {
  let nodes = nodes_for_range(1, 3)
  let edges = edges_from_tuples([#(1, 2), #(2, 3)])
  let assert Ok(_) = promote_to_graph(nodes, edges)
}

pub fn promote_to_graph_with_missing_node_test() {
  let nodes = nodes_for_range(1, 3)
  let edges = edges_from_tuples([#(1, 2), #(2, 4)])
  let assert Error(message) = promote_to_graph(nodes, edges)

  should.equal(message, "Edge references missing node: 4")
}

pub fn restore_session_has_same_dag_test() {
  let nodes = nodes_for_range(1, 3)
  let edges = edges_from_tuples([#(1, 2), #(2, 3)])

  let assert Ok(graph) = promote_to_graph(nodes, edges)
  let assert Ok(dag) = promote_to_dag(graph)

  let session = create_session(dag)

  should.equal(get_dag(session), get_dag(session_from(nodes, edges)))
}
