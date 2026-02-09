// import Testing
// @testable import ECScore

// @Test("create a query plan (like entt Registry.view<T1, T2 ...>)")
// func queryPlanTest() async throws {
//     let plan = QueryPlan()
//         .addWith(Position.self, Position.self, Position.self)
//         .addWithOut(Position.self, Position.self, MockComponentA.self, MockComponentB.self)
        
//     #expect(plan.with.count == 3)
//     #expect(plan.without.count == 4)

//     let plan2 = plan.addWith(Position.self, Position.self)
//     #expect(plan2.with.count == 5)

//     var plan_val = Raw(value: plan2).upgrade(QueryPlanFacts.self)
//     let ok1 = validate(validated: &plan_val, .include_list_unique)
//     let ok2 = validate(validated: &plan_val, .exclude_list_unique)
//     let ok3 = validate(validated: &plan_val, .both_list_merged_unique)
    
//     #expect(!ok1 && !ok2 && !ok3)

//     let plan3 = QueryPlan()
//         .addWith(Position.self)
//         .addWithOut(MockComponentA.self, MockComponentB.self)

//     var plan_val2 = Raw(value: plan3).upgrade(QueryPlanFacts.self)
//     validate(validated: &plan_val2, .include_list_unique)
//     validate(validated: &plan_val2, .exclude_list_unique)
//     validate(validated: &plan_val2, .both_list_merged_unique)

//     guard case let .success(result) = plan_val2.certify(Proof_ValidQueryPlan.self) else {
//         fatalError()
//     }

//     #expect(!result.flags.isEmpty)

// }