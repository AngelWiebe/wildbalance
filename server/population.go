package main

import "math"

// updateDirectorPopulation turns the director's population targets into extra
// animals in the world. The original pair and lead wolf remain the core game
// actors; added animals are a low-impact herd and pack extension.
func updateDirectorPopulation(tick uint64) {
	activeExtras := directorDeerTarget - 2
	for slot, id := range []string{"deer-3", "deer-4", "deer-5", "deer-6"} {
		meadowIndex := []int{4, 6, 5, 7}[slot]
		if slot < activeExtras {
			if _, exists := ambientDeerStates[id]; !exists {
				spawn := meadowTarget(meadowIndex, id)
				ambientDeerStates[id] = DeerState{
					X: spawn.X, Z: spawn.Z, Activity: "grazing", Alive: true,
					MeadowIndex: meadowIndex,
				}
			}
			delete(retiringDeer, id)
			continue
		}

		if _, exists := ambientDeerStates[id]; exists {
			if remaining, retiring := retiringDeer[id]; retiring {
				if remaining == 0 {
					delete(ambientDeerStates, id)
					delete(retiringDeer, id)
				} else {
					retiringDeer[id] = remaining - 1
				}
			} else {
				// Keep several "dead" snapshots so the client can remove the model.
				retiringDeer[id] = 6
			}
		}
	}

	for id, deer := range ambientDeerStates {
		if _, retiring := retiringDeer[id]; retiring {
			continue
		}
		if deer.RestTicks > 0 {
			deer.RestTicks--
			deer.Activity = "resting"
			ambientDeerStates[id] = deer
			continue
		}
		if meadowFood[deer.MeadowIndex] < 0.18 {
			deer.MeadowIndex = chooseMeadow(deer, -1)
		}

		target := meadowTarget(deer.MeadowIndex, id)
		distanceFromWolf := math.Hypot(deer.X-wolf.X, deer.Z-wolf.Z)
		isHuntNearby := (wolf.Activity == "hunting" || wolf.Activity == "feeding" || herdAlertTicks > 0) && distanceFromWolf < 14.0
		isThreat := wolf.TargetID == id || isHuntNearby
		if wolf.Activity == "feeding" && wolf.TargetID == id {
			deer.Activity = "caught"
			ambientDeerStates[id] = deer
			continue
		}
		if isThreat {
			deltaX, deltaZ := deer.X-wolf.X, deer.Z-wolf.Z
			distance := math.Hypot(deltaX, deltaZ)
			if distance < 0.01 {
				deltaX, deltaZ, distance = 1.0, 0.0, 1.0
			}
			target.X, target.Z = clampToWorld(
				deer.X+deltaX/distance*6.0,
				deer.Z+deltaZ/distance*6.0,
			)
			deer.Activity = "fleeing"
			deer.X, deer.Z = moveToward(deer.X, deer.Z, target.X, target.Z, 0.18)
			ambientDeerStates[id] = deer
			continue
		}

		if math.Hypot(target.X-deer.X, target.Z-deer.Z) < grazingArrivalDistance {
			deer.Activity = "grazing"
			deer.GrazingTicks++
			if meadowFood[deer.MeadowIndex] > 0.0 {
				meadowFood[deer.MeadowIndex] = clamp(meadowFood[deer.MeadowIndex]-0.0035, 0.0, 1.0)
			}
			if deer.GrazingTicks >= 120 {
				deer.RestTicks = 85
				deer.GrazingTicks = 0
			}
		} else {
			deer.Activity = "walking"
			deer.GrazingTicks = 0
			deer.X, deer.Z = moveToward(deer.X, deer.Z, target.X, target.Z, 0.08)
		}
		ambientDeerStates[id] = deer
	}

	if directorWolfTarget < 2 {
		// Keep the pack mate visible in the world even when the director lowers
		// pressure. It retreats to the den instead of disappearing entirely.
		packWolf.Activity = "resting"
		packWolf.X, packWolf.Z = moveToward(packWolf.X, packWolf.Z, -10.0, -8.0, 0.06)
		return
	}

	// The pack mate follows the lead wolf at a stable offset. It visually and
	// spatially represents increased predator pressure without doubling kills.
	packWolf.Activity = wolf.Activity
	if packWolf.Activity == "feeding" {
		packWolf.Activity = "wandering"
	}
	packWolf.Hunger = wolf.Hunger
	offsetX := -1.7 + math.Cos(float64(tick)*0.04)*0.5
	offsetZ := 1.4 + math.Sin(float64(tick)*0.035)*0.5
	step := 0.14
	if wolf.Activity == "hunting" {
		step = directorWolfStep * 0.92
	}
	packWolf.X, packWolf.Z = moveToward(packWolf.X, packWolf.Z, wolf.X+offsetX, wolf.Z+offsetZ, step)
}
