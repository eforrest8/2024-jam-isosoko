import ecstates

type
  CounterComponent = object
    kind: static[ComponentKind] = 0
    count: int = 0

proc init(): void =
  let counterId = createEntity()
  addComponent(counterId, CounterComponent.kind, CounterComponent())

proc run(): void =
  for e in entitiesWith(CounterComponent.kind):
    e.components.get(CounterComponent.kind).count.inc()
