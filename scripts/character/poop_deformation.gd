extends RefCounted

const Rules = preload("res://scripts/squish_rules.gd")
const MAX_STRETCH := 155.0
var anchor := Vector2.ZERO
var pull_target := Vector2.ZERO
var pull := Vector2.ZERO
var pull_velocity := Vector2.ZERO
var neighbor_pull := Vector2.ZERO
var dent := 0.0
var dent_velocity := 0.0
var squeeze := 0.0
var time := 0.0
var entrance := 1.0
var holding := false
var tremble := 0.0
var inflation := 1.0

func reset() -> void:
	anchor = Vector2.ZERO
	pull_target = Vector2.ZERO
	pull = Vector2.ZERO
	pull_velocity = Vector2.ZERO
	neighbor_pull = Vector2.ZERO
	dent = 0.0
	dent_velocity = 0.0
	squeeze = 0.0
	holding = false
	tremble = 0.0
	inflation = 1.0
	entrance = 0.0

func tap(point: Vector2) -> void:
	anchor = point
	holding = true
	pull_target = Vector2.ZERO
	dent_velocity += 210.0

func drag(displacement: Vector2) -> void:
	pull_target = displacement.limit_length(MAX_STRETCH)

func release() -> void:
	holding = false
	pull_target = Vector2.ZERO
	dent_velocity -= 105.0

func step(delta: float, pressure_ratio: float, rigidity: float = 1.0) -> void:
	# Substeps bound integration error without discarding real elapsed time.
	var remaining := delta
	while remaining > 0.0:
		var dt := minf(remaining, 1.0 / 120.0)
		remaining -= dt
		time += dt
		entrance = minf(1.0, entrance + dt * 4.5)
		var result := Rules.spring_step(pull, pull_velocity, pull_target, dt, 92.0 * rigidity, 14.0)
		pull = result[0]
		pull_velocity = result[1]
		neighbor_pull = neighbor_pull.lerp(pull, 1.0 - exp(-8.0 * dt))
		var target := (15.0 + 39.0 * pressure_ratio) / rigidity if holding else 0.0
		dent_velocity += ((target - dent) * 115.0 - dent_velocity * 15.0) * dt
		dent += dent_velocity * dt
		squeeze = lerpf(squeeze, pressure_ratio if holding else 0.0, 1.0 - exp(-10.0 * dt))

func warp(point: Vector2) -> Vector2:
	var influence := exp(-point.distance_squared_to(anchor) / (2.0 * 130.0 * 130.0))
	var broad := exp(-point.distance_squared_to(anchor) / (2.0 * 240.0 * 240.0))
	var inward := (-anchor).normalized() if anchor.length() > 25.0 else Vector2(0, 1)
	var local := point * Vector2(1.0 + squeeze * 0.075, 1.0 - squeeze * 0.065)
	local += inward * dent * influence
	local += pull * influence * 0.82 + neighbor_pull * broad * 0.18
	local.y += sin(time * 2.6) * 2.7
	local.x *= 1.0 + sin(time * 2.6) * 0.008
	# A small overshoot on spawn; never collapse the mesh to a singular point.
	var pop := 0.84 + 0.16 * entrance + sin(entrance * PI) * 0.09
	local *= Vector2(1.0 / pop, pop)
	local += Vector2(sin(time * 87.0), cos(time * 73.0)) * tremble
	return local * inflation
