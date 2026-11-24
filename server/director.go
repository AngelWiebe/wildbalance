package main

import "fmt"

// updateEcosystemDirector is the simulation's ecology decision layer. It does
// not script individual animals; instead it adjusts the pressure on the whole
// system based on available food, herd size, predator hunger, and the season.
func updateEcosystemDirector(tick uint64) {
	if tick%directorReviewTicks != 0 {
		return
	}
	if stewardPopulationManaged {
		defer func() {
			directorDeerTarget = stewardDeerTarget
			directorWolfTarget = stewardWolfTarget
			// A lone wolf still exists in the scene, but it hunts less often and
			// more slowly than a full pack. This makes the pack control a real
			// ecological decision rather than a purely visual setting.
			if stewardWolfTarget == 1 {
				directorHuntThreshold += 0.18
				directorWolfStep *= 0.72
			}
			directorStatus = fmt.Sprintf(
				"STEWARD  •  HERD %d  •  PACK %d",
				stewardDeerTarget,
				stewardWolfTarget,
			)
		}()
	}

	livingDeer := 0
	for _, deer := range deerStates {
		if deer.Alive {
			livingDeer++
		}
	}

	averageFood := 0.0
	for _, food := range meadowFood {
		averageFood += food
	}
	averageFood /= float64(len(meadowFood))

	// A normal run begins as a proper herd and a two-wolf pack.
	directorHuntThreshold = 0.55
	directorWolfStep = 0.30
	directorRespawnDelay = 120
	directorDeerTarget = 4
	directorWolfTarget = 2
	directorStatus = "DIRECTOR  •  herd and pack stable; normal pressure"

	if livingDeer == 0 {
		directorHuntThreshold = 1.0
		directorWolfStep = 0.035
		directorRespawnDelay = 45
		directorDeerTarget = 2
		directorWolfTarget = 1
		directorStatus = "DIRECTOR  •  rebuilding the herd; predator resting"
		return
	}

	if averageFood < 0.24 {
		directorHuntThreshold = 0.82
		directorWolfStep = 0.16
		directorRespawnDelay = 170
		directorDeerTarget = 3
		directorWolfTarget = 1
		directorStatus = "DIRECTOR  •  protecting depleted meadows; predator pressure reduced"
		return
	}

	if livingDeer == 1 {
		directorHuntThreshold = 0.78
		directorWolfStep = 0.18
		directorRespawnDelay = 60
		directorDeerTarget = 3
		directorWolfTarget = 1
		directorStatus = "DIRECTOR  •  rebuilding herd; wolf hunting cautiously"
		return
	}

	if averageFood > 0.76 && wolf.Hunger > 0.65 {
		directorHuntThreshold = 0.48
		directorWolfStep = 0.34
		directorDeerTarget = 5
		directorStatus = "DIRECTOR  •  forage abundant; expanding the herd"
		if averageFood > 0.88 && seasons[seasonIndex] != "WINTER" {
			directorDeerTarget = 6
			directorWolfTarget = 2
			directorStatus = "DIRECTOR  •  abundant habitat; a wolf pack is forming"
		}
		return
	}

	if seasons[seasonIndex] == "WINTER" {
		directorHuntThreshold = 0.68
		directorWolfStep = 0.22
		directorRespawnDelay = 155
		directorDeerTarget = 3
		directorWolfTarget = 1
		directorStatus = "DIRECTOR  •  winter conservation; slower recovery"
	}
}

func adjustStewardPopulation(species string, delta int) {
	if delta != -1 && delta != 1 {
		return
	}

	stewardPopulationManaged = true
	switch species {
	case "deer":
		stewardDeerTarget = max(2, min(6, stewardDeerTarget+delta))
	case "wolf":
		stewardWolfTarget = max(1, min(2, stewardWolfTarget+delta))
	default:
		return
	}

	directorDeerTarget = stewardDeerTarget
	directorWolfTarget = stewardWolfTarget
	directorStatus = fmt.Sprintf(
		"STEWARD  •  HERD %d  •  PACK %d",
		stewardDeerTarget,
		stewardWolfTarget,
	)
}
