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

pub type EdgeRelation(a) {
  EdgeRelation(a)
}

pub type Edge(a) {
  Edge(relation: EdgeRelation(a), from: NodeId, to: NodeId)
}

type AdjList(b) =
  Dict(NodeId, List(#(NodeId, EdgeRelation(b))))

pub opaque type Graph(a, b) {
  Graph(nodes: List(Node(a)), adj_list: AdjList(b))
}

pub type Event(a) {
  Event(String, a)
}

pub opaque type DAG(a, b) {
  DAG(Graph(a, b))
}

// TODO: track update handlers
pub opaque type Session(a, b) {
  Session(
    dag: DAG(a, b),
    adj_list: AdjList(b),
    in_degree: Dict(NodeId, Int),
    out_degree: Dict(NodeId, Int),
    node_lookup: Dict(NodeId, Node(a)),
  )
}

pub fn promote_to_graph(nodes: List(Node(a)), edges: List(Edge(b))) {
  let node_ids = list.map(nodes, fn(node) { node.id })
  let edge_ids = list.flat_map(edges, fn(edge) { [edge.from, edge.to] })
  let missing_node =
    list.find(edge_ids, fn(id) { !list.contains(node_ids, id) })
  case missing_node {
    Ok(NodeId(id)) -> Error("Edge references missing node: " <> id)
    Error(_) -> {
      let adj_list: AdjList(b) =
        list.fold(edges, dict.new(), fn(acc, edge) {
          let neighbors = dict.get(acc, edge.from) |> result.unwrap([])
          dict.insert(
            acc,
            edge.from,
            list.append(neighbors, [#(edge.to, edge.relation)]),
          )
        })
      Ok(Graph(nodes, adj_list))
    }
  }
}

pub fn empty_session() -> Session(a, b) {
  Session(
    dag: DAG(Graph([], dict.new())),
    adj_list: dict.new(),
    in_degree: dict.new(),
    out_degree: dict.new(),
    node_lookup: dict.new(),
  )
}

pub fn get_dag(session: Session(a, b)) -> DAG(a, b) {
  session.dag
}

pub fn create_session(dag: DAG(a, b)) -> Session(a, b) {
  let DAG(graph) = dag
  let in_degree =
    list.fold(graph.nodes, dict.new(), fn(acc, node) {
      dict.insert(acc, node.id, 0)
    })
  let out_degree =
    list.fold(graph.nodes, dict.new(), fn(acc, node) {
      dict.insert(acc, node.id, 0)
    })
  let node_lookup =
    list.fold(graph.nodes, dict.new(), fn(acc, node) {
      dict.insert(acc, node.id, node)
    })
  Session(
    dag: dag,
    adj_list: graph.adj_list,
    in_degree: in_degree,
    out_degree: out_degree,
    node_lookup: node_lookup,
  )
}

pub fn promote_to_dag(graph: Graph(a, b)) -> Result(DAG(a, b), String) {
  case has_cycle(graph) {
    True -> Error("Graph has a cycle.")
    False -> Ok(DAG(graph))
  }
}

// TODO: update session state (instead of create_session)
pub fn add_node(
  session: Session(a, b),
  node: Node(a),
  update_handler: fn(Event(a)) -> Result(Nil, String),
) -> Result(Session(a, b), String) {
  case dict.get(session.node_lookup, node.id) {
    Ok(Node(NodeId(id), _)) -> Error("Node already exists: " <> id)
    _ -> {
      let result = update_handler(Event("add_node", node.data))
      case result {
        Error(err) -> Error(err)
        Ok(_) -> {
          let DAG(graph) = session.dag
          let new_graph =
            Graph(nodes: [node, ..graph.nodes], adj_list: graph.adj_list)
          let new_dag = DAG(new_graph)
          Ok(create_session(new_dag))
        }
      }
    }
  }
}

// TODO: reject if the edge already exists
// TODO: reject if the edge would create a cycle
// TODO: reject if the edge's nodes do not exist
// TODO: Only check for cycles in the subgraph that includes the new edge
// TODO: update session state (instead of create_session)
pub fn add_edge(
  session: Session(a, b),
  edge: Edge(b),
  update_handler: fn(Event(Edge(b))) -> Result(Nil, String),
) -> Result(Session(a, b), String) {
  let has_from_node = dict.has_key(session.node_lookup, edge.from)
  let has_to_node = dict.has_key(session.node_lookup, edge.to)
  case has_from_node, has_to_node {
    False, _ -> Error("From node does not exist: " <> string.inspect(edge.from))
    _, False -> Error("To node does not exist: " <> string.inspect(edge.to))
    True, True -> {
      let DAG(graph) = session.dag
      let result = update_handler(Event("add_edge", edge))
      case result {
        Error(err) -> Error(err)
        Ok(_) -> {
          let updated_adj_list: AdjList(b) =
            dict.insert(
              graph.adj_list,
              edge.from,
              list.append(
                dict.get(graph.adj_list, edge.from) |> result.unwrap([]),
                [#(edge.to, edge.relation)],
              ),
            )
          Ok(
            create_session(
              DAG(Graph(nodes: graph.nodes, adj_list: updated_adj_list)),
            ),
          )
        }
      }
    }
  }
}

// TODO: why is this using map? Every node should have a unique id.
// TODO: call update_handler
// TODO: reject if the node does not exist
// TODO: update session state (instead of create_session)
pub fn update_node_data(
  session: Session(a, b),
  node_id: NodeId,
  new_data: a,
) -> Result(Session(a, b), String) {
  let DAG(Graph(nodes, edges)) = session.dag
  let updated_nodes =
    list.map(nodes, fn(node) {
      case node {
        Node(id, _) if id == node_id -> Node(id, new_data)
        _ -> node
      }
    })
  Ok(create_session(DAG(Graph(updated_nodes, edges))))
}

// TODO: reject if the edge does not exist
// TODO: reject if the edge would create a cycle
// TODO: reject if the either of the edge's nodes do not exist
// TODO: update session state
pub fn update_edge(
  session: Session(a, b),
  old_edge: Edge(b),
  new_edge: Edge(b),
) -> Result(Session(a, b), String) {
  // Implementation
  todo
}

// TODO: reject if the edge does not exist
// TODO: update session state
pub fn delete_edge(
  session: Session(a, b),
  edge: Edge(b),
) -> Result(Session(a, b), String) {
  // Implementation
  todo
}

// TODO: reject if the node does not exist
// TODO: delete immediate downstream edges
// TODO: update session state
pub fn delete_node(
  session: Session(a, b),
  node_id: NodeId,
) -> Result(Session(a, b), String) {
  // Implementation
  todo
}

// TODO: reject if the node does not exist
// TODO: delete everything downstream that would be orphaned
// TODO: update session state
pub fn delete_node_and_orphans(
  session: Session(a, b),
  node_id: NodeId,
) -> Result(Session(a, b), String) {
  // Implementation
  todo
}

pub fn visit_topological(
  session: Session(a, b),
  visitor: fn(Node(a)) -> Option(Node(a)),
) -> Result(Nil, String) {
  // Implementation
  todo
}

pub fn has_cycle(graph: Graph(a, b)) -> Bool {
  let Graph(nodes, adj_list) = graph
  let visited =
    list.fold(nodes, dict.new(), fn(acc, node) {
      dict.insert(acc, node.id, False)
    })
  let rec_stack =
    list.fold(nodes, dict.new(), fn(acc, node) {
      dict.insert(acc, node.id, False)
    })

  list.any(nodes, fn(node) {
    case dict.get(visited, node.id) {
      Ok(False) -> {
        io.println("Starting DFS for node: " <> string.inspect(node.id))
        let adj_list_with_relations: Dict(NodeId, List(NodeId)) =
          dict.fold(adj_list, dict.new(), fn(acc, key, neighbors) {
            dict.insert(
              acc,
              key,
              list.map(neighbors, fn(neighbor_pair) { neighbor_pair.0 }),
            )
          })
        dfs(node.id, visited, rec_stack, adj_list_with_relations, [node.id])
      }
      _ -> False
    }
  })
}

fn dfs(
  node_id: NodeId,
  visited: Dict(NodeId, Bool),
  rec_stack: Dict(NodeId, Bool),
  adj_list: Dict(NodeId, List(NodeId)),
  stack: List(NodeId),
) -> Bool {
  case stack {
    [] -> False
    [current, ..rest] ->
      case dict.get(visited, current) {
        Ok(True) ->
          case dict.get(rec_stack, current) {
            Ok(True) -> True
            _ -> dfs(node_id, visited, rec_stack, adj_list, rest)
          }
        _ -> {
          let visited = dict.insert(visited, current, True)
          let rec_stack = dict.insert(rec_stack, current, True)
          let neighbors = dict.get(adj_list, current) |> result.unwrap([])
          let new_stack = list.append(neighbors, rest)
          dfs(node_id, visited, rec_stack, adj_list, new_stack)
        }
      }
  }
}
