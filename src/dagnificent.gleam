import dagnificent/graph
import gleam/dict.{type Dict}
import gleam/list
import gleam/result

pub opaque type DAG(a, b) {
  DAG(graph.Graph(a, b))
}

pub fn new() -> DAG(a, b) {
  DAG(graph.new())
}

pub fn get_raw_data(dag: DAG(a, b)) -> graph.RawData(a, b) {
  let DAG(graph) = dag
  graph.get_raw_data(graph)
}

pub fn upsert_node(
  dag: DAG(a, b),
  node: graph.Node(a),
) -> Result(DAG(a, b), String) {
  let DAG(graph) = dag
  use graph <- result.try(graph.upsert_node(graph, node))
  Ok(DAG(graph))
}

pub fn delete_node(
  dag: DAG(a, b),
  node_id: graph.NodeId,
) -> Result(DAG(a, b), String) {
  let DAG(graph) = dag
  use graph <- result.try(graph.delete_node(graph, node_id))
  Ok(DAG(graph))
}

pub fn upsert_edge(
  dag: DAG(a, b),
  edge: graph.Edge(b),
) -> Result(DAG(a, b), String) {
  // First, use the graph.upsert_edge function to update the graph
  let DAG(graph) = dag
  use graph <- result.try(graph.upsert_edge(graph, edge))

  // Then, ensure that it doesn't create a cycle
  case has_cycle_from(graph, edge.to) {
    True -> Error("Cannot create edge that would create a cycle")
    False -> Ok(DAG(graph))
  }
}

pub fn delete_edge(
  dag: DAG(a, b),
  edge: graph.Edge(b),
) -> Result(DAG(a, b), String) {
  let DAG(graph) = dag
  use graph <- result.try(graph.delete_edge(graph, edge))
  Ok(DAG(graph))
}

fn has_cycle_from(graph: graph.Graph(a, b), start: graph.NodeId) -> Bool {
  let raw_data = graph.get_raw_data(graph)
  let adj_list = raw_data.adj_list
  let visited = dict.new()
  let rec_stack = dict.new()
  detect_cycle_from(adj_list, start, visited, rec_stack)
}

fn detect_cycle_from(
  adj_list: graph.AdjList(b),
  node: graph.NodeId,
  visited: Dict(graph.NodeId, Bool),
  rec_stack: Dict(graph.NodeId, Bool),
) -> Bool {
  case dict.get(rec_stack, node) {
    Ok(True) -> True
    _ -> {
      case dict.get(visited, node) {
        Ok(True) -> False
        _ -> {
          let visited = dict.insert(visited, node, True)
          let rec_stack = dict.insert(rec_stack, node, True)
          let neighbors = dict.get(adj_list, node) |> result.unwrap([])
          list.any(neighbors, fn(neighbor_pair) {
            detect_cycle_from(adj_list, neighbor_pair.0, visited, rec_stack)
          })
        }
      }
    }
  }
}
