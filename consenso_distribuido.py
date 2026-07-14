from dataclasses import dataclass, field
from typing import List, Optional, Tuple

LogEntry = Tuple[int, str]

@dataclass
class Node:
    "Representa un servidor participante del clúster Raft."

    node_id: int
    state: str = "FOLLOWER"
    current_term: int = 0
    voted_for: Optional[int] = None
    log: List[LogEntry] = field(default_factory=list)
    commit_index: int = -1
    alive: bool = True

    def last_log_info(self) -> Tuple[int, int]:
        "Devuelve índice y término de la última entrada del registro."
        if not self.log:
            return -1, 0
        return len(self.log) - 1, self.log[-1][0]

    def request_vote(
        self,
        candidate_id: int,
        candidate_term: int,
        candidate_last_index: int,
        candidate_last_term: int,
    ) -> bool:
        "Procesa una solicitud de voto de un candidato."
        if not self.alive:
            return False

        if candidate_term < self.current_term:
            return False

        if candidate_term > self.current_term:
            self.current_term = candidate_term
            self.voted_for = None
            self.state = "FOLLOWER"

        own_last_index, own_last_term = self.last_log_info()
        candidate_is_up_to_date = (
            candidate_last_term > own_last_term
            or (
                candidate_last_term == own_last_term
                and candidate_last_index >= own_last_index
            )
        )

        can_vote = self.voted_for in (None, candidate_id)
        if can_vote and candidate_is_up_to_date:
            self.voted_for = candidate_id
            return True
        return False

    def append_entries(
        self,
        leader_term: int,
        leader_id: int,
        leader_log: List[LogEntry],
        leader_commit: int,
    ) -> bool:
        "Recibe el registro del líder y lo replica si el término es válido."
        if not self.alive or leader_term < self.current_term:
            return False

        self.current_term = leader_term
        self.state = "FOLLOWER"
        self.voted_for = None
        self.log = list(leader_log)
        self.commit_index = min(leader_commit, len(self.log) - 1)
        print(
            f"Nodo {self.node_id}: AppendEntries recibido del líder {leader_id}; "
            f"log={self.log}, commit_index={self.commit_index}"
        )
        return True


class RaftCluster:
    "Coordina la simulación síncrona de un clúster Raft."

    def __init__(self, number_of_nodes: int = 3) -> None:
        if number_of_nodes < 3:
            raise ValueError("El prototipo requiere al menos tres nodos.")
        self.nodes = [Node(node_id=i) for i in range(number_of_nodes)]
        self.leader_id: Optional[int] = None

    @property
    def majority(self) -> int:
        "Cantidad mínima de votos o réplicas para formar mayoría."
        return len(self.nodes) // 2 + 1

    def elect_leader(self, candidate_id: int) -> bool:
        "Inicia una elección y declara líder al candidato con mayoría."
        candidate = self.nodes[candidate_id]
        if not candidate.alive:
            print(f"Nodo {candidate_id}: no puede competir porque está inactivo.")
            return False

        new_term = max(node.current_term for node in self.nodes) + 1
        candidate.current_term = new_term
        candidate.state = "CANDIDATE"
        candidate.voted_for = candidate_id
        votes = 1

        last_index, last_term = candidate.last_log_info()
        print(
            f"\nNodo {candidate_id}: inicia elección para el término {new_term} "
            f"con log final ({last_index}, término {last_term})."
        )
        print(f"Nodo {candidate_id}: se vota a sí mismo.")

        for node in self.nodes:
            if node.node_id == candidate_id:
                continue
            granted = node.request_vote(
                candidate_id,
                new_term,
                last_index,
                last_term,
            )
            status = "concede" if granted else "rechaza"
            print(f"Nodo {node.node_id}: {status} el voto al nodo {candidate_id}.")
            votes += int(granted)

        if votes >= self.majority:
            candidate.state = "LEADER"
            self.leader_id = candidate_id
            print(
                f"Nodo {candidate_id}: elegido LÍDER con {votes} votos "
                f"de {len(self.nodes)}."
            )
            return True

        candidate.state = "FOLLOWER"
        print(f"Nodo {candidate_id}: elección fallida; recibió {votes} votos.")
        return False

    def replicate_value(self, command: str) -> bool:
        "Replica un valor desde el líder y lo confirma con una mayoría."
        if self.leader_id is None:
            print("No existe un líder activo para replicar el valor.")
            return False

        leader = self.nodes[self.leader_id]
        if not leader.alive or leader.state != "LEADER":
            print("El líder registrado no está disponible.")
            return False

        leader.log.append((leader.current_term, command))
        new_index = len(leader.log) - 1
        acknowledgements = 1
        print(
            f"\nLíder {leader.node_id}: propone '{command}' "
            f"en el índice {new_index}."
        )

        for follower in self.nodes:
            if follower.node_id == leader.node_id:
                continue
            accepted = follower.append_entries(
                leader_term=leader.current_term,
                leader_id=leader.node_id,
                leader_log=leader.log,
                leader_commit=leader.commit_index,
            )
            acknowledgements += int(accepted)

        if acknowledgements >= self.majority:
            leader.commit_index = new_index
            print(
                f"Líder {leader.node_id}: '{command}' confirmado por mayoría "
                f"({acknowledgements}/{len(self.nodes)})."
            )
            self._broadcast_commit()
            return True

        print(
            f"Líder {leader.node_id}: no obtuvo mayoría; "
            f"la entrada '{command}' no se confirma."
        )
        return False

    def _broadcast_commit(self) -> None:
        "Propaga el índice confirmado a los seguidores disponibles."
        if self.leader_id is None:
            return
        leader = self.nodes[self.leader_id]
        for follower in self.nodes:
            if follower.node_id == leader.node_id:
                continue
            follower.append_entries(
                leader_term=leader.current_term,
                leader_id=leader.node_id,
                leader_log=leader.log,
                leader_commit=leader.commit_index,
            )

    def fail_leader(self) -> None:
        "Simula que el líder deja de responder."
        if self.leader_id is None:
            print("No hay líder para simular el fallo.")
            return
        leader = self.nodes[self.leader_id]
        leader.alive = False
        leader.state = "FAILED"
        print(f"\n*** FALLO SIMULADO: el líder {leader.node_id} dejó de responder. ***")
        self.leader_id = None

    def recover_node(self, node_id: int) -> None:
        "Reactiva un nodo y sincroniza su registro con el líder actual."
        node = self.nodes[node_id]
        node.alive = True
        node.state = "FOLLOWER"
        node.voted_for = None
        print(f"\nNodo {node_id}: vuelve a estar disponible.")

        if self.leader_id is None:
            print("No existe líder para sincronizar el nodo recuperado.")
            return

        leader = self.nodes[self.leader_id]
        node.append_entries(
            leader_term=leader.current_term,
            leader_id=leader.node_id,
            leader_log=leader.log,
            leader_commit=leader.commit_index,
        )
        print(f"Nodo {node_id}: registro actualizado desde el líder {leader.node_id}.")

    def show_status(self) -> None:
        "Muestra el estado final de todos los nodos."
        print("\nESTADO DEL CLÚSTER")
        for node in self.nodes:
            print(
                f"Nodo {node.node_id}: estado={node.state}, vivo={node.alive}, "
                f"término={node.current_term}, commit_index={node.commit_index}, "
                f"log={node.log}"
            )


def main() -> None:
    "Ejecuta el escenario completo solicitado en la actividad."
    cluster = RaftCluster(number_of_nodes=3)

    # Primera elección y acuerdo del valor A=1.
    cluster.elect_leader(candidate_id=0)
    cluster.replicate_value("A=1")

    # El líder falla; los nodos restantes mantienen una mayoría de 2 sobre 3.
    cluster.fail_leader()

    # Nueva elección y continuación del servicio con un segundo valor.
    cluster.elect_leader(candidate_id=1)
    cluster.replicate_value("B=2")

    # El antiguo líder regresa y recibe el registro actualizado.
    cluster.recover_node(node_id=0)
    cluster.show_status()


if __name__ == "__main__":
    main()
