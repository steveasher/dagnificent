import gleam/int
import graph.{type Edge, type Node, Edge, Node, NodeId}

pub fn a_node(data: Int) -> Node(Int) {
  Node(id: NodeId(int.to_string(data)), data: data)
}

pub fn an_edge(from: Int, to: Int) -> Edge(String) {
  Edge(
    relation: graph.EdgeRelation("->"),
    from: NodeId(int.to_string(from)),
    to: NodeId(int.to_string(to)),
  )
}
