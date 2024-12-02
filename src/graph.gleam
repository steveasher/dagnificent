import gleam/bool
import gleam/dict.{type Dict}
import gleam/io
import gleam/list
import gleam/option.{type Option}
import gleam/result
import gleam/string

pub type NodeId {
  NodeId(String)
}

pub type Node(a) {
  Node(id: NodeId, data: a)
}

pub type EdgeRelation(c) {
  EdgeRelation(c)
}

pub type Edge(c) {
  Edge(relation: EdgeRelation(c), from: NodeId, to: NodeId)
}

type AdjList(b) =
  Dict(NodeId, List(#(NodeId, EdgeRelation(b))))

pub opaque type Graph(a, b) {
  Graph(nodes: Dict(NodeId, a), adj_list: AdjList(b))
}

pub type RawData(a, b) {
  RawData(nodes: Dict(NodeId, a), adj_list: AdjList(b))
}

pub type WriteOperation(a, b) {
  UpsertNode(Node(a))
  DeleteNode(NodeId)
  UpsertEdge(Edge(b))
  DeleteEdge(Edge(b))
}

fn upsert_node(graph: Graph(a, b), node: Node(a)) -> Result(Graph(a, b), String) {
  let new_nodes = dict.insert(graph.nodes, node.id, node.data)
  Ok(Graph(nodes: new_nodes, adj_list: graph.adj_list))
}

fn delete_node(
  graph: Graph(a, b),
  node_id: NodeId,
) -> Result(Graph(a, b), String) {
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

fn upsert_edge(graph: Graph(a, b), edge: Edge(b)) -> Result(Graph(a, b), String) {
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

fn delete_edge(graph: Graph(a, b), edge: Edge(b)) -> Result(Graph(a, b), String) {
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

pub fn new() -> Graph(a, b) {
  Graph(nodes: dict.new(), adj_list: dict.new())
}

pub fn atomic_update(
  graph: Graph(a, b),
  operations: List(WriteOperation(a, b)),
) -> Result(Graph(a, b), String) {
  list.fold(operations, Ok(graph), apply_write_operation)
}

pub fn apply_update(
  result: Graph(a, b),
  operation: WriteOperation(a, b),
) -> Result(Graph(a, b), String) {
  string.inspect(result)
  apply_write_operation(Ok(result), operation)
}

fn apply_write_operation(
  result: Result(Graph(a, b), String),
  operation: WriteOperation(a, b),
) -> Result(Graph(a, b), String) {
  case result {
    Error(_) -> result
    Ok(graph) -> {
      case operation {
        UpsertNode(node) -> upsert_node(graph, node)
        DeleteNode(node_id) -> delete_node(graph, node_id)
        UpsertEdge(edge) -> upsert_edge(graph, edge)
        DeleteEdge(edge) -> delete_edge(graph, edge)
      }
    }
  }
}

pub fn get_raw_data(graph: Graph(a, b)) -> RawData(a, b) {
  RawData(nodes: graph.nodes, adj_list: graph.adj_list)
}
