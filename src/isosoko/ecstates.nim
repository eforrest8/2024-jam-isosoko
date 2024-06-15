import std/tables
import bucket
import std/sets

type
  ComponentPtr = ptr object
  ComponentKind* = int16
  ComponentId = int16
  ComponentTable = Table[ComponentKind, Bucket[ComponentPtr]]
  EntityId = int16
  Entity* = tuple[id: EntityId, components: Table[ComponentKind, ComponentId]]
  State = tuple[entities: Bucket[Entity], components: ComponentTable]

var activeState: State

iterator componentsOfKind*(kind: ComponentKind): ComponentPtr =
  for e in activeState.components.getOrDefault(kind).items:
    yield e

iterator entitiesMatching*(pattern: set[ComponentKind]): ComponentPtr =
  for e in activeState.entities.items:
    let eKinds: set[ComponentKind] = set(e.components.keys)
    if intersection(pattern, eKinds).card == card pattern:
      yield e

iterator entitiesWith*(kind: ComponentKind): Entity =
  for e in activeState.entities.items:
    if kind in e.components:
      yield e

### create a new entity and return its id
proc createEntity*(): EntityId =
  return EntityId(activeState.entities.incl(Entity()))

proc addComponent*(ent: EntityId, kind: ComponentKind, comp: object): void =
  let id = activeState.components.hasKeyOrPut(kind, Bucket[ComponentPtr]()).incl(addr comp)
  activeState.entities[ent].components.add(kind, id)
