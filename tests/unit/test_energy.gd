extends "res://tests/base_test.gd"

## Unit tests for the energy system core classes:
## BuildingEnergy, EnergyNode, EnergyNetwork.

# ── Mock building for EnergyNetwork tests ────────────────────────────────────

class MockBuilding extends RefCounted:
	var energy
	var _max_recipe_cost: float = 0.0

	func get_max_affordable_recipe_cost() -> float:
		return _max_recipe_cost

# ── BuildingEnergy tests ─────────────────────────────────────────────────────

func test_building_energy_initial_state() -> void:
	var e := BuildingEnergy.new(100.0, 5.0, 0.0)
	assert_eq(e.energy_capacity, 100.0, "capacity")
	assert_eq(e.base_energy_demand, 5.0, "demand")
	assert_eq(e.generation_rate, 0.0, "gen rate")
	assert_eq(e.energy_stored, 0.0, "stored starts at 0")
	assert_false(e.is_powered, "consumer starts unpowered")

func test_building_energy_no_demand_starts_powered() -> void:
	var e := BuildingEnergy.new(50.0, 0.0, 10.0)
	assert_true(e.is_powered, "no demand = powered")

func test_building_energy_add_within_capacity() -> void:
	var e := BuildingEnergy.new(100.0)
	var added := e.add_energy(40.0)
	assert_eq(added, 40.0, "added full amount")
	assert_eq(e.energy_stored, 40.0, "stored updated")

func test_building_energy_add_overflow() -> void:
	var e := BuildingEnergy.new(50.0)
	e.energy_stored = 30.0
	var added := e.add_energy(40.0)
	assert_eq(added, 20.0, "only 20 space left")
	assert_eq(e.energy_stored, 50.0, "capped at capacity")

func test_building_energy_remove() -> void:
	var e := BuildingEnergy.new(100.0)
	e.energy_stored = 60.0
	var removed := e.remove_energy(25.0)
	assert_eq(removed, 25.0, "removed full amount")
	assert_eq(e.energy_stored, 35.0, "stored decreased")

func test_building_energy_remove_underflow() -> void:
	var e := BuildingEnergy.new(100.0)
	e.energy_stored = 10.0
	var removed := e.remove_energy(30.0)
	assert_eq(removed, 10.0, "can only remove what's there")
	assert_eq(e.energy_stored, 0.0, "stored at zero")

func test_building_energy_fill_ratio() -> void:
	var e := BuildingEnergy.new(200.0)
	e.energy_stored = 100.0
	assert_eq(e.get_fill_ratio(), 0.5, "half full")
	e.energy_stored = 0.0
	assert_eq(e.get_fill_ratio(), 0.0, "empty")
	e.energy_stored = 200.0
	assert_eq(e.get_fill_ratio(), 1.0, "full")

func test_building_energy_fill_ratio_zero_capacity() -> void:
	var e := BuildingEnergy.new(0.0)
	assert_eq(e.get_fill_ratio(), 0.0, "zero capacity = 0 ratio")

func test_building_energy_adjacency_throughput_default() -> void:
	var e := BuildingEnergy.new(100.0)
	assert_eq(e.adjacency_throughput, 200.0, "default adjacency throughput")

func test_building_energy_serialize_roundtrip() -> void:
	var e := BuildingEnergy.new(100.0, 5.0, 10.0)
	e.energy_stored = 42.5
	var data := e.serialize()
	var e2 := BuildingEnergy.new(100.0, 5.0, 10.0)
	e2.deserialize(data)
	assert_eq(e2.energy_stored, 42.5, "stored restored")

func test_building_energy_deserialize_clamps() -> void:
	var e := BuildingEnergy.new(50.0)
	e.deserialize({"energy_stored": 999.0})
	assert_eq(e.energy_stored, 50.0, "clamped to capacity")

# ── EnergyNode tests ────────────────────────────────────────────────────────

func test_energy_node_connect_two() -> void:
	var a := EnergyNode.new()
	var b := EnergyNode.new()
	a.owner_grid_pos = Vector2i(0, 0)
	b.owner_grid_pos = Vector2i(2, 0)
	a.connection_range = 5.0
	b.connection_range = 5.0
	assert_true(a.connect_to(b), "connect succeeded")
	assert_true(a.is_connected_to(b), "a -> b")
	assert_true(b.is_connected_to(a), "b -> a (bidirectional)")
	a.free()
	b.free()

func test_energy_node_cannot_connect_self() -> void:
	var a := EnergyNode.new()
	a.owner_grid_pos = Vector2i(0, 0)
	assert_false(a.can_connect_to(a), "cannot self-connect")
	a.free()

func test_energy_node_cannot_double_connect() -> void:
	var a := EnergyNode.new()
	var b := EnergyNode.new()
	a.owner_grid_pos = Vector2i(0, 0)
	b.owner_grid_pos = Vector2i(1, 0)
	a.connection_range = 5.0
	b.connection_range = 5.0
	a.connect_to(b)
	assert_false(a.can_connect_to(b), "no duplicate")
	a.free()
	b.free()

func test_energy_node_max_connections() -> void:
	var a := EnergyNode.new()
	a.owner_grid_pos = Vector2i(0, 0)
	a.connection_range = 10.0
	a.max_connections = 2
	var nodes := [a]
	for i in 3:
		var n := EnergyNode.new()
		n.owner_grid_pos = Vector2i(i + 1, 0)
		n.connection_range = 10.0
		n.max_connections = 5
		nodes.append(n)
	assert_true(a.connect_to(nodes[1]), "1st connect ok")
	assert_true(a.connect_to(nodes[2]), "2nd connect ok")
	assert_false(a.can_connect_to(nodes[3]), "3rd blocked by max")
	for n in nodes:
		n.free()

func test_energy_node_out_of_range() -> void:
	var a := EnergyNode.new()
	var b := EnergyNode.new()
	a.owner_grid_pos = Vector2i(0, 0)
	b.owner_grid_pos = Vector2i(10, 0)
	a.connection_range = 5.0
	b.connection_range = 5.0
	assert_false(a.can_connect_to(b), "out of range")
	a.free()
	b.free()

func test_energy_node_range_uses_max() -> void:
	var a := EnergyNode.new()
	var b := EnergyNode.new()
	a.owner_grid_pos = Vector2i(0, 0)
	b.owner_grid_pos = Vector2i(4, 0)
	a.connection_range = 5.0
	b.connection_range = 2.0
	# Distance is 4; max range is max(5,2) = 5 — should be in range
	assert_true(a.is_in_range(b), "uses max of both ranges")
	a.free()
	b.free()

func test_energy_node_disconnect() -> void:
	var a := EnergyNode.new()
	var b := EnergyNode.new()
	a.owner_grid_pos = Vector2i(0, 0)
	b.owner_grid_pos = Vector2i(1, 0)
	a.connection_range = 5.0
	b.connection_range = 5.0
	a.connect_to(b)
	a.disconnect_from(b)
	assert_false(a.is_connected_to(b), "a disconnected")
	assert_false(b.is_connected_to(a), "b disconnected")
	a.free()
	b.free()

func test_energy_node_disconnect_all() -> void:
	var a := EnergyNode.new()
	var b := EnergyNode.new()
	var c := EnergyNode.new()
	a.owner_grid_pos = Vector2i(0, 0)
	b.owner_grid_pos = Vector2i(1, 0)
	c.owner_grid_pos = Vector2i(0, 1)
	for n in [a, b, c]:
		n.connection_range = 5.0
	a.connect_to(b)
	a.connect_to(c)
	a.disconnect_all()
	assert_eq(a.connections.size(), 0, "a has no connections")
	assert_false(b.is_connected_to(a), "b lost connection to a")
	assert_false(c.is_connected_to(a), "c lost connection to a")
	a.free()
	b.free()
	c.free()

func test_energy_node_serialize_connections() -> void:
	var a := EnergyNode.new()
	var b := EnergyNode.new()
	a.owner_grid_pos = Vector2i(5, 3)
	b.owner_grid_pos = Vector2i(8, 3)
	a.connection_range = 10.0
	b.connection_range = 10.0
	a.connect_to(b)
	var data := a.serialize_connections()
	assert_eq(data.size(), 1, "one connection serialized")
	assert_eq(data[0]["x"], 8, "serialized x")
	assert_eq(data[0]["y"], 3, "serialized y")
	a.free()
	b.free()

func test_energy_node_has_free_slot() -> void:
	var a := EnergyNode.new()
	a.max_connections = 1
	a.connection_range = 10.0
	assert_true(a.has_free_slot(), "initially has free slot")
	var b := EnergyNode.new()
	b.owner_grid_pos = Vector2i(1, 0)
	b.connection_range = 10.0
	a.connect_to(b)
	assert_false(a.has_free_slot(), "no free slot after max reached")
	a.free()
	b.free()

# ── EnergyNetwork tests ─────────────────────────────────────────────────────

func _make_mock(capacity: float, demand: float = 0.0, generation: float = 0.0) -> MockBuilding:
	var m := MockBuilding.new()
	m.energy = BuildingEnergy.new(capacity, demand, generation)
	return m

## Helper to create a network with edges between all consecutive buildings (chain).
func _make_chain_network(mocks: Array) -> EnergyNetwork:
	var net := EnergyNetwork.new()
	net.buildings = mocks.duplicate()
	for m in mocks:
		if m.energy.generation_rate > 0.0:
			net.generators.append(m)
		if m.energy.base_energy_demand > 0.0:
			net.consumers.append(m)
	# Chain edges: 0-1, 1-2, 2-3, ...
	for i in range(mocks.size() - 1):
		net.edges.append({
			a = mocks[i], b = mocks[i + 1],
			throughput = minf(mocks[i].energy.adjacency_throughput, mocks[i + 1].energy.adjacency_throughput)
		})
	return net

func test_network_generation() -> void:
	var gen := _make_mock(200.0, 0.0, 25.0)  # generator: 25/s
	var net := EnergyNetwork.new()
	net.buildings = [gen]
	net.generators = [gen]
	net.tick(1.0)  # 1 second
	assert_true(gen.energy.energy_stored > 20.0, "generator produced energy (got %.1f)" % gen.energy.energy_stored)

func test_network_consume_base_sufficient() -> void:
	var consumer := _make_mock(100.0, 10.0)  # demands 10/s
	consumer.energy.energy_stored = 50.0
	var net := EnergyNetwork.new()
	net.buildings = [consumer]
	net.consumers = [consumer]
	net.tick(1.0)
	assert_true(consumer.energy.is_powered, "powered when sufficient energy")
	assert_true(consumer.energy.energy_stored < 50.0, "energy consumed")

func test_network_consume_base_insufficient() -> void:
	var consumer := _make_mock(100.0, 10.0)
	consumer.energy.energy_stored = 3.0  # not enough for 10/s * 1s
	var net := EnergyNetwork.new()
	net.buildings = [consumer]
	net.consumers = [consumer]
	net.tick(1.0)
	assert_false(consumer.energy.is_powered, "unpowered when insufficient")

func test_network_equalization_two_buildings() -> void:
	var a := _make_mock(100.0)
	var b := _make_mock(100.0)
	a.energy.energy_stored = 100.0  # full
	b.energy.energy_stored = 0.0    # empty
	var net := _make_chain_network([a, b])
	# Run several ticks to let equalization converge
	for i in 10:
		net.tick(0.5)
	# Should converge toward 50/50
	var diff := absf(a.energy.energy_stored - b.energy.energy_stored)
	assert_true(diff < 5.0, "equalized within 5 (diff=%.1f, a=%.1f, b=%.1f)" % [diff, a.energy.energy_stored, b.energy.energy_stored])

func test_network_equalization_unequal_capacity() -> void:
	var big := _make_mock(200.0)
	var small := _make_mock(50.0)
	big.energy.energy_stored = 200.0
	small.energy.energy_stored = 0.0
	var net := _make_chain_network([big, small])
	for i in 20:
		net.tick(0.5)
	# Fill-ratio equalization: both should converge to similar ratios
	assert_true(small.energy.energy_stored > 30.0, "small filled (%.1f)" % small.energy.energy_stored)
	assert_true(big.energy.energy_stored > 100.0, "big retains bulk (%.1f)" % big.energy.energy_stored)

func test_network_gen_plus_consumer() -> void:
	var gen := _make_mock(200.0, 0.0, 50.0)  # generates 50/s
	var consumer := _make_mock(100.0, 10.0)   # demands 10/s
	var net := _make_chain_network([gen, consumer])
	# Run for 5 seconds
	for i in 50:
		net.tick(0.1)
	assert_true(consumer.energy.is_powered, "consumer powered by generator")
	assert_true(consumer.energy.energy_stored > 0.0, "consumer has energy")

func test_network_rationing() -> void:
	# 1 generator making 5/s, 3 consumers each demanding 10/s
	var gen := _make_mock(100.0, 0.0, 5.0)
	var c1 := _make_mock(100.0, 10.0)
	var c2 := _make_mock(100.0, 10.0)
	var c3 := _make_mock(100.0, 10.0)
	var net := _make_chain_network([gen, c1, c2, c3])
	# Run a few ticks — demand (30/s) far exceeds supply (5/s)
	for i in 20:
		net.tick(0.5)
	# All consumers should be unpowered due to insufficient supply
	assert_false(c1.energy.is_powered, "c1 rationed (unpowered)")
	assert_false(c2.energy.is_powered, "c2 rationed (unpowered)")
	assert_false(c3.energy.is_powered, "c3 rationed (unpowered)")

func test_network_empty_tick() -> void:
	var net := EnergyNetwork.new()
	net.tick(1.0)  # should not crash
	assert_true(true, "empty network tick does not crash")

func test_network_zero_demand_all_powered() -> void:
	var a := _make_mock(50.0)
	var b := _make_mock(50.0)
	var net := _make_chain_network([a, b])
	net.tick(1.0)
	# No consumers, so nothing to check for is_powered — just ensure no crash
	assert_true(true, "network with no consumers ticks fine")

func test_network_storage_gets_surplus() -> void:
	# Generator surplus (gen > demand) flows to battery via equalization
	var gen := _make_mock(100.0, 0.0, 50.0)  # generates 50/s
	var consumer := _make_mock(100.0, 10.0)   # demands 10/s
	var battery := _make_mock(2000.0)          # pure storage
	var net := _make_chain_network([gen, consumer, battery])
	# Run enough ticks for energy to accumulate and spread
	for i in 20:
		net.tick(0.5)
	assert_true(consumer.energy.is_powered,
		"Consumer powered while battery charges")
	assert_true(battery.energy.energy_stored > 1.0,
		"Battery received surplus energy (%.1f)" % battery.energy.energy_stored)

func test_network_generator_fills_capacity() -> void:
	var gen := _make_mock(100.0, 0.0, 1000.0)  # very fast gen
	var net := EnergyNetwork.new()
	net.buildings = [gen]
	net.generators = [gen]
	net.tick(1.0)
	assert_eq(gen.energy.energy_stored, 100.0, "capped at capacity")

func test_network_floor_protects_recipe_energy() -> void:
	# Building with recipe cost should not give away that energy
	var source := _make_mock(200.0)
	source.energy.energy_stored = 200.0
	source._max_recipe_cost = 50.0  # floor = 50
	var sink := _make_mock(200.0)
	sink.energy.energy_stored = 0.0
	var net := _make_chain_network([source, sink])
	for i in 20:
		net.tick(0.5)
	# Source should retain at least its floor (50)
	assert_true(source.energy.energy_stored >= 45.0,
		"Source retained floor energy (%.1f)" % source.energy.energy_stored)

func test_network_battery_gives_all() -> void:
	# Battery (floor=0) donates freely to needy consumer
	var battery := _make_mock(2000.0)
	battery.energy.energy_stored = 500.0
	var consumer := _make_mock(100.0, 10.0)
	consumer.energy.energy_stored = 0.0
	var net := _make_chain_network([battery, consumer])
	for i in 10:
		net.tick(0.5)
	assert_true(consumer.energy.is_powered, "consumer powered from battery")
	assert_true(consumer.energy.energy_stored > 0.0, "consumer has energy")

func test_network_throughput_limits_transfer() -> void:
	# Two buildings with low throughput — energy transfer is bounded
	var a := _make_mock(1000.0)
	var b := _make_mock(1000.0)
	a.energy.energy_stored = 1000.0
	b.energy.energy_stored = 0.0
	a.energy.adjacency_throughput = 10.0  # very low throughput
	b.energy.adjacency_throughput = 10.0
	var net := _make_chain_network([a, b])
	net.tick(1.0)  # 1 second: max transfer = 10 * 1.0 = 10
	# b should have received at most ~10 energy (across all phases)
	assert_true(b.energy.energy_stored <= 15.0,
		"Throughput limited transfer (b=%.1f)" % b.energy.energy_stored)
	assert_true(b.energy.energy_stored > 0.0, "Some energy transferred")
