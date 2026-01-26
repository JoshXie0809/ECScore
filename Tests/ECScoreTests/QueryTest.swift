import Testing
@testable import ECScore

@Test("create a query plan (like entt Registry.view<T1, T2 ...>)")
func queryPlanTest() async throws {
    let plan = QueryPlan()
        .addWith(Position.self, Position.self, Position.self)
        .addWithOut(Position.self, Position.self, MockComponentA.self, MockComponentB.self)
        
    #expect(plan.with.count == 3)
    #expect(plan.without.count == 4)

    let plan2 = plan.addWith(Position.self, Position.self)
    #expect(plan2.with.count == 5)

    var plan_val = Raw(value: plan2).upgrade(QueryPlanFacts.self)
    let ok1 = validate(validated: &plan_val, QueryPlanFacts.FlagCase.include_list_unique.rawValue)
    let ok2 = validate(validated: &plan_val, QueryPlanFacts.FlagCase.exclude_list_unique.rawValue)
    let ok3 = validate(validated: &plan_val, QueryPlanFacts.FlagCase.both_list_merged_unique.rawValue)
    
    #expect(!ok1 && !ok2 && !ok3)

    let plan3 = QueryPlan()
        .addWith(Position.self)
        .addWithOut(MockComponentA.self, MockComponentB.self)

    var plan_val2 = Raw(value: plan3).upgrade(QueryPlanFacts.self)
    validate(validated: &plan_val2, QueryPlanFacts.FlagCase.include_list_unique.rawValue)
    validate(validated: &plan_val2, QueryPlanFacts.FlagCase.exclude_list_unique.rawValue)
    validate(validated: &plan_val2, QueryPlanFacts.FlagCase.both_list_merged_unique.rawValue)

    guard case let .success(result) = plan_val2.certify(Proof_ValidQueryPlan.self) else {
        fatalError()
    }

    #expect(!result.flags.isEmpty)

}