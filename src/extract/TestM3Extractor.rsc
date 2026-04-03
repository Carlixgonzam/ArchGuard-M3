module extract::TestM3Extractor

import extract::M3Extractor;
import analysis::m3::Core;
import lang::java::m3::Core;
import Set;

M3 sampleModel() = m3(|project://sample|,
  containment = {
    <|java+package:///com/example/orders|,
     |java+compilationUnit:///com/example/orders/OrderController.java|>,
    <|java+package:///com/example/payments|,
     |java+compilationUnit:///com/example/payments/PaymentService.java|>,
    <|java+package:///com/example/inventory|,
     |java+compilationUnit:///com/example/inventory/StockManager.java|>
  },
  methodInvocation = {
    <|java+method:///com/example/orders/OrderController/create()|,
     |java+method:///com/example/payments/PaymentService/charge()|>,
    <|java+method:///com/example/orders/OrderController/fulfill()|,
     |java+method:///com/example/inventory/StockManager/reserve()|>,
    <|java+method:///com/example/orders/OrderController/validate()|,
     |java+method:///com/example/orders/OrderValidator/check()|>
  },
  typeDependency = {
    <|java+class:///com/example/orders/OrderController|,
     |java+class:///com/example/payments/PaymentService|>,
    <|java+class:///com/example/orders/OrderController|,
     |java+class:///com/example/inventory/StockManager|>
  },
  annotations = {
    <|java+method:///com/example/orders/OrderController/create()|,
     |java+class:///org/springframework/web/bind/annotation/PostMapping|>,
    <|java+method:///com/example/orders/OrderController/getAll()|,
     |java+class:///org/springframework/web/bind/annotation/GetMapping|>,
    <|java+class:///com/example/inventory/InventoryEntity|,
     |java+class:///javax/persistence/Entity|>,
    <|java+class:///com/example/payments/PaymentRepository|,
     |java+class:///org/springframework/stereotype/Repository|>
  }
);

M3 emptyModel() = m3(|project://empty|);

test bool discoverFindsAllServices() =
  discoverServices(sampleModel(), 2) == {"orders", "payments", "inventory"};

test bool invocationsCrossServiceOnly() =
  extractInvocations(sampleModel(), 2) == {<"orders", "payments">, <"orders", "inventory">};

test bool invocationsExcludeSameService() =
  <"orders", "orders"> notin extractInvocations(sampleModel(), 2);

test bool typeDependenciesCrossService() =
  extractTypeDependencies(sampleModel(), 2) == {<"orders", "payments">, <"orders", "inventory">};

test bool endpointsDetectSpringAnnotations() =
  extractEndpoints(sampleModel(), 2) ==
    {<"orders", "/com/example/orders/OrderController/create()">,
     <"orders", "/com/example/orders/OrderController/getAll()">};

test bool dbEntitiesDetectJpaAndRepository() =
  extractDbEntities(sampleModel(), 2) ==
    {<"inventory", "/com/example/inventory/InventoryEntity">,
     <"payments", "/com/example/payments/PaymentRepository">};

test bool fullExtractionIntegration() {
  ExtractionResult r = extractFromModel(sampleModel(), 2);
  return r.services == {"orders", "payments", "inventory"}
      && size(r.invocations) == 2
      && size(r.typeDependencies) == 2
      && size(r.endpoints) == 2
      && size(r.dbEntities) == 2;
}

test bool segmentAtExtractsCorrectly() =
  segmentAt("/com/example/orders", 2) == "orders";

test bool segmentAtOutOfBounds() =
  segmentAt("/com", 5) == "";

test bool segmentAtEmptyPath() =
  segmentAt("", 0) == "";

test bool differentDepthChangesService() =
  discoverServices(sampleModel(), 1) == {"example"};

test bool emptyModelNoServices() =
  discoverServices(emptyModel(), 2) == {};

test bool emptyModelNoInvocations() =
  extractInvocations(emptyModel(), 2) == {};

test bool emptyModelNoTypeDeps() =
  extractTypeDependencies(emptyModel(), 2) == {};

test bool emptyModelNoEndpoints() =
  extractEndpoints(emptyModel(), 2) == {};

test bool emptyModelNoDbEntities() =
  extractDbEntities(emptyModel(), 2) == {};
