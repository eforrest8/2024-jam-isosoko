import std/tables
import bucket
import std/sets

type
  ComponentPtr = ptr object
  ComponentKind = int16
  ComponentId = int16
  ComponentTable = Table[ComponentKind, Bucket[ComponentPtr]]
  EntityId = int16
  Entity = tuple[id: EntityId, components: Table[ComponentKind, ComponentId]]
  State = tuple[entities: Bucket[Entity], components: ComponentTable]

iterator componentsOfKind*(self: State, kind: ComponentKind): ComponentPtr =
  for e in self.components.getOrDefault(kind).items:
    yield e

iterator entitiesMatching*(self: State, pattern: set[ComponentKind]): ComponentPtr =
  for e in self.entities.items:
    let eKinds: set[ComponentKind] = set(e.components.keys)
    if intersection(pattern, eKinds).card == card pattern:
      yield e

iterator entitiesWith*(self: State, kind: ComponentKind): ComponentPtr =
  for e in self.entities.items:
    if kind in e.components:
      yield e

### create a new entity and return its id
proc createEntity(self: State): EntityId =
  return EntityId(self.entities.incl(Entity()))

proc addComponent(self: State, ent: EntityId, kind: ComponentKind, comp: object): void =
  let id = self.components.hasKeyOrPut(kind, Bucket[ComponentPtr]()).incl(addr comp)
  self.entities[ent].components.add(kind, id)

var globalState = State()
