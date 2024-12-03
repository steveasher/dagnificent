import gleam/bool
import gleam/dict.{type Dict}
import gleam/list
import gleam/option
import gleam/string

pub type NodeId {
  NodeId(String)
}

pub type Node(data) {
  Node(id: NodeId, data: data)
}

pub type EdgeRelation(relation) {
  EdgeRelation(relation)
}

pub type Edge(relation) {
  Edge(relation: EdgeRelation(relation), from: NodeId, to: NodeId)
}

type AdjList(relation) =
  Dict(NodeId, List(#(NodeId, EdgeRelation(relation))))

pub opaque type Graph(data, relation) {
  Graph(nodes: Dict(NodeId, data), adj_list: AdjList(relation))
}

pub type RawData(data, relation) {
  RawData(nodes: Dict(NodeId, data), adj_list: AdjList(relation))
}

pub fn upsert_node(
  graph: Graph(data, relation),
  node: Node(data),
) -> Result(Graph(data, relation), String) {
  let new_nodes = dict.insert(graph.nodes, node.id, node.data)
  Ok(Graph(nodes: new_nodes, adj_list: graph.adj_list))
}

pub fn delete_node(
  graph: Graph(data, relation),
  node_id: NodeId,
) -> Result(Graph(data, relation), String) {
  // Check if the adjacency list contains edges from the given node
  case dict.get(graph.adj_list, node_id) {
    // If there are no edges from the given node, remove the node from the graph
    Error(_) -> {
      Ok(Graph(
        nodes: dict.delete(graph.nodes, node_id),
        adj_list: graph.adj_list,
      ))
    }
    // If there are edges from the given node
    Ok(_edges) -> {
      // Remove the node from the adjacency list and the nodes dictionary
      let new_adj_list = dict.delete(graph.adj_list, node_id)
      Ok(Graph(nodes: dict.delete(graph.nodes, node_id), adj_list: new_adj_list))
    }
  }
}

pub fn upsert_edge(
  graph: Graph(data, relation),
  edge: Edge(relation),
) -> Result(Graph(data, relation), String) {
  use <- bool.guard(
    when: bool.or(
      !dict.has_key(graph.nodes, edge.from),
      !dict.has_key(graph.nodes, edge.to),
    ),
    return: Error("Edge would invalidate graph: " <> string.inspect(edge)),
  )

  let #(from, to) = #(edge.from, edge.to)
  let new_adj_list =
    graph.adj_list
    |> dict.upsert(from, fn(edges) {
      [#(to, edge.relation), ..option.unwrap(edges, [])]
    })
  Ok(Graph(nodes: graph.nodes, adj_list: new_adj_list))
}

pub fn delete_edge(
  graph: Graph(data, relation),
  edge: Edge(relation),
) -> Result(Graph(data, relation), String) {
  // Check if the adjacency list contains edges from the given node
  case dict.get(graph.adj_list, edge.from) {
    // If there are no edges from the given node, return the original graph
    Error(_) -> Ok(graph)
    // If there are edges from the given node
    Ok(edges) -> {
      // Filter out the edge that matches the given edge's destination node
      let new_edges = list.filter(edges, fn(e) { e.0 != edge.to })
      case new_edges {
        // If no edges remain after filtering, remove the node from the adjacency list
        [] -> {
          let new_adj_list = dict.delete(graph.adj_list, edge.from)
          Ok(Graph(nodes: graph.nodes, adj_list: new_adj_list))
        }
        // If there are still edges remaining, update the adjacency list with the new edges
        _ -> {
          let new_adj_list = dict.insert(graph.adj_list, edge.from, new_edges)
          Ok(Graph(nodes: graph.nodes, adj_list: new_adj_list))
        }
      }
    }
  }
}

pub fn new() -> Graph(data, relation) {
  Graph(nodes: dict.new(), adj_list: dict.new())
}

pub fn get_raw_data(graph: Graph(data, relation)) -> RawData(data, relation) {
  RawData(nodes: graph.nodes, adj_list: graph.adj_list)
}
