package main

import "math"

const worldMinX = -48.0
const worldMaxX = 36.0
const worldMinZ = -48.0
const worldMaxZ = 44.0

func clamp(value, low, high float64) float64 {
	return math.Max(low, math.Min(high, value))
}

func moveToward(x, z, targetX, targetZ, step float64) (float64, float64) {
	deltaX := targetX - x
	deltaZ := targetZ - z
	distance := math.Hypot(deltaX, deltaZ)
	if distance <= step || distance == 0.0 {
		return targetX, targetZ
	}
	return x + deltaX/distance*step, z + deltaZ/distance*step
}

func clampToWorld(x, z float64) (float64, float64) {
	return clamp(x, worldMinX, worldMaxX), clamp(z, worldMinZ, worldMaxZ)
}

func chooseMeadow(deer DeerState, avoidIndex int) int {
	bestIndex := deer.MeadowIndex
	bestScore := -math.MaxFloat64
	for index, meadow := range meadowRoute {
		distance := math.Hypot(meadow.X-deer.X, meadow.Z-deer.Z)
		score := meadowFood[index]*10.0 - distance
		if index == avoidIndex {
			score -= 3.0
		}
		if score > bestScore {
			bestScore = score
			bestIndex = index
		}
	}
	return bestIndex
}

func safestMeadow() int {
	bestIndex := 0
	bestScore := -math.MaxFloat64
	for index, meadow := range meadowRoute {
		distanceFromWolf := math.Hypot(meadow.X-wolf.X, meadow.Z-wolf.Z)
		score := distanceFromWolf + meadowFood[index]*2.0
		if score > bestScore {
			bestScore = score
			bestIndex = index
		}
	}
	return bestIndex
}

func meadowTarget(meadowIndex int, deerID string) MeadowPoint {
	meadow := meadowRoute[meadowIndex]

	// Each deer gets a stable, separate grazing position inside a meadow.
	// This prevents two deer from endlessly trying to occupy the same center point.
	if deerID == "deer-1" {
		return MeadowPoint{X: meadow.X - 0.72, Z: meadow.Z + 0.38}
	}

	return MeadowPoint{X: meadow.X + 0.72, Z: meadow.Z - 0.38}
}

func respawnDeer(id string) DeerState {
	meadowIndex := safestMeadow()
	spawn := meadowTarget(meadowIndex, id)
	hungerByDeer[id] = 0.35
	delete(fleeTargets, id)
	return DeerState{
		X:           spawn.X,
		Z:           spawn.Z,
		Activity:    "grazing",
		Alive:       true,
		SafeTicks:   80,
		MeadowIndex: meadowIndex,
	}
}

// updateDeerNeed gives each deer a small, independent decision cycle. Hunger
// drives foraging; well-fed deer occasionally settle and rest at a safe meadow.
func updateDeerNeed(id string, deer *DeerState, avoidMeadow int, tick uint64) {
	if !deer.Alive {
		return
	}
	if deer.RestTicks > 0 {
		deer.RestTicks--
		return
	}
	if deer.DecisionTicks > 0 {
		deer.DecisionTicks--
		return
	}

	deer.DecisionTicks = 35 + uint64(len(id))*4
	hunger := hungerByDeer[id]
	food := meadowFood[deer.MeadowIndex]
	if food < 0.22 || hunger > 0.64 {
		deer.MeadowIndex = chooseMeadow(*deer, avoidMeadow)
		return
	}

	// Staggered clocks stop both deer from making exactly the same choice.
	if hunger < 0.42 && food > 0.42 && (tick/10+uint64(len(id)))%3 == 0 {
		// Long enough for the lay-down, rest loop, and get-up actions to read.
		deer.RestTicks = 85
	}
}

type wolfTarget struct {
	ID string
	X  float64
	Z  float64
}

func availableWolfTargets() []wolfTarget {
	targets := make([]wolfTarget, 0, len(deerStates)+len(ambientDeerStates))
	for id, deer := range deerStates {
		if deer.Alive && deer.SafeTicks == 0 {
			targets = append(targets, wolfTarget{ID: id, X: deer.X, Z: deer.Z})
		}
	}
	for id, deer := range ambientDeerStates {
		if deer.Alive {
			if _, retiring := retiringDeer[id]; !retiring {
				targets = append(targets, wolfTarget{ID: id, X: deer.X, Z: deer.Z})
			}
		}
	}
	return targets
}

func catchWolfTarget(id string) {
	if deer, exists := deerStates[id]; exists {
		deer.Alive = false
		deer.Activity = "dead"
		deer.RespawnTicks = directorRespawnDelay
		deerStates[id] = deer
		delete(fleeTargets, id)
		return
	}

	if deer, exists := ambientDeerStates[id]; exists {
		deer.Alive = false
		deer.Activity = "dead"
		ambientDeerStates[id] = deer
		retiringDeer[id] = 6
	}
}

func updateWolf(tick uint64) {
	if wolfRetreatTicks > 0 {
		wolfRetreatTicks--
		wolf.TargetID = ""
		wolf.FeedTicks = 0
		wolf.Activity = "retreating"
		retreatX := -10.0 + math.Cos(float64(tick)*0.03)*1.5
		retreatZ := -8.0 + math.Sin(float64(tick)*0.02)*1.5
		wolf.X, wolf.Z = moveToward(wolf.X, wolf.Z, retreatX, retreatZ, 0.16)
		return
	}

	if wolf.FeedTicks > 0 {
		wolf.FeedTicks--
		wolf.Activity = "feeding"
		wolf.Hunger = clamp(wolf.Hunger-0.01, 0.15, 1.0)
		if wolf.FeedTicks == 0 && wolf.TargetID != "" {
			catchWolfTarget(wolf.TargetID)
			wolf.TargetID = ""
			wolf.RestTicks = 55
		}
		return
	}

	if wolf.RestTicks > 0 {
		wolf.RestTicks--
		wolf.Activity = "resting"
		denX, denZ := -8.0, -6.0
		wolf.X, wolf.Z = moveToward(wolf.X, wolf.Z, denX, denZ, 0.045)
		wolf.Hunger = clamp(wolf.Hunger+0.0007, 0.15, 1.0)
		return
	}

	targets := availableWolfTargets()
	if wolf.Hunger >= directorHuntThreshold && len(targets) > 0 {
		closest := targets[0]
		closestDistance := math.Hypot(closest.X-wolf.X, closest.Z-wolf.Z)
		for _, candidate := range targets[1:] {
			distance := math.Hypot(candidate.X-wolf.X, candidate.Z-wolf.Z)
			if distance < closestDistance {
				closest = candidate
				closestDistance = distance
			}
		}
		wolf.TargetID = closest.ID
		targetX, targetZ := closest.X, closest.Z
		wolf.Activity = "hunting"
		wolf.X, wolf.Z = moveToward(wolf.X, wolf.Z, targetX, targetZ, directorWolfStep)
		if math.Hypot(targetX-wolf.X, targetZ-wolf.Z) < 1.05 {
			wolf.Activity = "feeding"
			wolf.FeedTicks = 40
		}
		return
	}

	wolf.Activity = "wandering"
	wanderX := -7.5 + math.Cos(float64(tick)*0.018)*3.2
	wanderZ := -5.0 + math.Sin(float64(tick)*0.014)*2.6
	wolf.X, wolf.Z = moveToward(wolf.X, wolf.Z, wanderX, wanderZ, 0.035)
	wolf.Hunger = clamp(wolf.Hunger+0.0015, 0.15, 1.0)
}

func fleeFromWolf(id string, routeX, routeZ float64) (float64, float64, bool) {
	target, hasTarget := fleeTargets[id]
	distanceFromWolf := math.Hypot(routeX-wolf.X, routeZ-wolf.Z)
	isHuntNearby := (wolf.Activity == "hunting" || wolf.Activity == "feeding" || herdAlertTicks > 0) && distanceFromWolf < 14.0
	isThreat := wolf.TargetID == id || isHuntNearby
	if isThreat {
		if !hasTarget {
			deltaX, deltaZ := routeX-wolf.X, routeZ-wolf.Z
			distance := math.Hypot(deltaX, deltaZ)
			if distance < 0.01 {
				deltaX, deltaZ, distance = 1.0, 0.0, 1.0
			}
			target.X, target.Z = clampToWorld(
				routeX+deltaX/distance*6.0,
				routeZ+deltaZ/distance*6.0,
			)
		}
		fleeTargets[id] = target
		return target.X, target.Z, true
	}
	if hasTarget {
		target.X, target.Z = moveToward(target.X, target.Z, routeX, routeZ, 0.05)
		if math.Hypot(target.X-routeX, target.Z-routeZ) < 0.06 {
			delete(fleeTargets, id)
			return routeX, routeZ, false
		}
		fleeTargets[id] = target
		return target.X, target.Z, false
	}
	return routeX, routeZ, false
}

func updateDeerState(id, activity string, meadowIndex int) {
	hungerChange := 0.0015
	deer := deerStates[id]
	if activity == "resting" {
		hungerChange = 0.0005
	}
	if activity == "grazing" && meadowFood[meadowIndex] > 0.0 {
		bite := math.Min(0.008, meadowFood[meadowIndex])
		meadowFood[meadowIndex] -= bite
		hungerChange = -bite * 1.1
		deer.GrazingTicks++
	} else if activity != "resting" {
		deer.GrazingTicks = 0
	}
	hungerByDeer[id] = clamp(hungerByDeer[id]+hungerChange, 0.20, 1.0)

	// A deer that has fed calmly for twelve seconds takes a proper rest.
	// This is deliberate rather than random so the lay-down behavior appears
	// regularly in normal play.
	if deer.Alive && deer.GrazingTicks >= 120 && hungerByDeer[id] <= 0.62 {
		deer.RestTicks = 85
		deer.GrazingTicks = 0
		deerStates[id] = deer
		return
	}
	deerStates[id] = deer

	if hungerByDeer[id] >= 0.995 {
		if deer.Alive {
			deer.Alive, deer.Activity, deer.RespawnTicks = false, "dead", directorRespawnDelay
			deerStates[id] = deer
			delete(fleeTargets, id)
		}
	}
}

func livingHerdCount() int {
	livingDeer := 0
	for _, deer := range deerStates {
		if deer.Alive {
			livingDeer++
		}
	}
	for id, deer := range ambientDeerStates {
		if !deer.Alive {
			continue
		}
		if _, retiring := retiringDeer[id]; !retiring {
			livingDeer++
		}
	}
	return livingDeer
}

func ecosystemBalance() float64 {
	livingDeer := livingHerdCount()
	totalFood := 0.0
	for _, food := range meadowFood {
		totalFood += food
	}

	// Four deer and a two-wolf pack are the healthy reference point. The herd
	// score falls on either side: too few deer signals predation pressure, while
	// too many overgraze the meadows and eventually pull the food score down.
	herdScore := clamp(35.0-math.Abs(float64(livingDeer-4))*11.0, 0.0, 35.0)
	foodScore := totalFood / float64(len(meadowFood)) * 45.0
	packScore := float64(directorWolfTarget) * 10.0
	return clamp(herdScore+foodScore+packScore, 0.0, 100.0)
}

func seasonFailureReason() string {
	if len(tendedMeadows) < 2 {
		return "The forest was not tended. Reseed two different meadows each season."
	}

	livingDeer := livingHerdCount()
	if livingDeer == 0 {
		return "The herd was lost. Use the wolf call earlier."
	}

	totalFood := 0.0
	for _, food := range meadowFood {
		totalFood += food
	}
	if totalFood/float64(len(meadowFood)) < 0.30 {
		return "Meadow food ran low. Reseed before the bars empty."
	}
	if wolf.Hunger > 0.75 {
		return "Predator pressure was too high. Use the wolf call."
	}
	return "Balance did not hold long enough this season."
}

func seasonalRegrowth() float64 {
	baseRate := 0.0015
	switch seasons[seasonIndex] {
	case "SPRING":
		baseRate = 0.0025
	case "SUMMER":
		baseRate = 0.0018
	case "AUTUMN":
		baseRate = 0.0012
	case "WINTER":
		baseRate = 0.0005
	}
	_, _, modifier := currentSeasonEvent()
	return baseRate * modifier
}

func currentSeasonEvent() (string, string, float64) {
	switch seasons[seasonIndex] {
	case "SPRING":
		return "NEW GROWTH", "meadows recover quickly", 1.25
	case "SUMMER":
		return "DRY SPELL", "reseed low meadows early", 0.65
	case "AUTUMN":
		return "FORAGE BOUNTY", "meadows recover quickly", 1.20
	case "WINTER":
		return "HARD FROST", "food recovery is very slow", 0.55
	default:
		return "CALM WEATHER", "conditions are stable", 1.0
	}
}
