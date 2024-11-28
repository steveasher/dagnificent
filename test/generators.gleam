import dagnificent.{
  type Edge, type Node, type NodeId, Edge, EdgeRelation, Node, NodeId,
}
import gleam/int
import gleam/list
import qcheck.{type Generator, map, tuple2}

// Generator for NodeId
pub fn node_id_gen() -> Generator(NodeId) {
  map(qcheck.small_strictly_positive_int(), fn(i) { NodeId(int.to_string(i)) })
}

pub fn one_of(list: List(a)) -> Generator(a) {
  let gens = list |> list.map(fn(i) { qcheck.return(i) })
  map(qcheck.from_generators(gens), fn(i) { i })
}

// Generator for Node
pub fn node_gen() -> Generator(Node(Int)) {
  map(node_id_gen(), fn(id) { Node(id: id, data: 0) })
}

// Generator for Edge
pub fn edge_gen(nodes: List(Node(Int))) -> Generator(Edge(String)) {
  map(tuple2(one_of(nodes), one_of(nodes)), fn(pair) {
    let #(from, to) = pair
    Edge(EdgeRelation("->"), from: from.id, to: to.id)
  })
}
