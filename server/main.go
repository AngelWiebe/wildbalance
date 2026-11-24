package main

import "math"

func updateSimulation(tick uint64) {
	stateMu.Lock()
	defer stateMu.Unlock()

	seasonTicks++
	if seasonReportTicks > 0 {
		seasonReportTicks--
	}

	if reseedCooldownTicks > 0 {
		reseedCooldownTicks--
	}
	if wolfCallCooldown > 0 {
		wolfCallCooldown--
	}

	updateEcosystemDirector(tick)
	updateDirectorPopulation(tick)

	if seasonTicks >= seasonLengthTicks {
		if seasonBalanceTicks >= balanceGoalTicks && len(tendedMeadows) >= 2 {
			seasonsBalanced = min(seasonsBalanced+1, seasonsToWin)
			lastSeasonResult = "SEASON BALANCED"
			lastSeasonReason = "The ecosystem stayed healthy."
		} else {
			lastSeasonResult = "SEASON UNBALANCED"
			lastSeasonReason = seasonFailureReason()
		}

		seasonTicks = 0
		seasonBalanceTicks = 0
		tendedMeadows = map[int]bool{}
		reseedsThisSeason = 0
		seasonReportTicks = 60
		seasonIndex = (seasonIndex + 1) % len(seasons)
	}

	deerOne := deerStates["deer-1"]
	deerTwo := deerStates["deer-2"]

	if deerOne.SafeTicks > 0 {
		deerOne.SafeTicks--
	}
	if deerTwo.SafeTicks > 0 {
		deerTwo.SafeTicks--
	}

	updateDeerNeed("deer-1", &deerOne, deerTwo.MeadowIndex, tick)
	updateDeerNeed("deer-2", &deerTwo, deerOne.MeadowIndex, tick)

	if deerOne.Alive &&
		meadowFood[deerOne.MeadowIndex] <= 0.12 {
		deerOne.MeadowIndex = chooseMeadow(
			deerOne,
			deerTwo.MeadowIndex,
		)
	}

	if deerTwo.Alive &&
		meadowFood[deerTwo.MeadowIndex] <= 0.12 {
		deerTwo.MeadowIndex = chooseMeadow(
			deerTwo,
			deerOne.MeadowIndex,
		)
	}

	meadowOne := deerOne.MeadowIndex
	routeOne := meadowTarget(meadowOne, "deer-1")
	routeOneX := routeOne.X
	routeOneZ := routeOne.Z
	routeOneActivity := "walking"
	if deerOne.RestTicks > 0 {
		routeOneActivity = "resting"
		routeOneX = deerOne.X
		routeOneZ = deerOne.Z
	}

	if routeOneActivity != "resting" && math.Hypot(
		routeOneX-deerOne.X,
		routeOneZ-deerOne.Z,
	) < grazingArrivalDistance {
		routeOneActivity = "grazing"
		routeOneX = deerOne.X
		routeOneZ = deerOne.Z
	}

	meadowTwo := deerTwo.MeadowIndex
	routeTwo := meadowTarget(meadowTwo, "deer-2")
	routeTwoX := routeTwo.X
	routeTwoZ := routeTwo.Z
	routeTwoActivity := "walking"
	if deerTwo.RestTicks > 0 {
		routeTwoActivity = "resting"
		routeTwoX = deerTwo.X
		routeTwoZ = deerTwo.Z
	}

	if routeTwoActivity != "resting" && math.Hypot(
		routeTwoX-deerTwo.X,
		routeTwoZ-deerTwo.Z,
	) < grazingArrivalDistance {
		routeTwoActivity = "grazing"
		routeTwoX = deerTwo.X
		routeTwoZ = deerTwo.Z
	}

	if !deerOne.Alive && deerOne.RespawnTicks > 0 {
		deerOne.RespawnTicks--

		if deerOne.RespawnTicks == 0 {
			deerOne = respawnDeer("deer-1")
		}

		deerStates["deer-1"] = deerOne
	}

	if !deerTwo.Alive && deerTwo.RespawnTicks > 0 {
		deerTwo.RespawnTicks--

		if deerTwo.RespawnTicks == 0 {
			deerTwo = respawnDeer("deer-2")
		}

		deerStates["deer-2"] = deerTwo
	}

	// Save the deer decisions made above before the wolf may inspect or change them.
	// Otherwise a later reload could discard a new meadow choice or safety countdown.
	deerStates["deer-1"] = deerOne
	deerStates["deer-2"] = deerTwo

	updateWolf(tick)

	// This must happen after updateWolf: a completed feeding phase can
	// mark its target as no longer alive.
	deerOne = deerStates["deer-1"]
	deerTwo = deerStates["deer-2"]

	deerOneDistance := math.Hypot(
		deerOne.X-wolf.X,
		deerOne.Z-wolf.Z,
	)

	deerTwoDistance := math.Hypot(
		deerTwo.X-wolf.X,
		deerTwo.Z-wolf.Z,
	)

	if wolf.Activity == "hunting" &&
		(deerOneDistance < 4.8 || deerTwoDistance < 4.8) {
		herdAlertTicks = 50
	}

	if herdAlertTicks > 0 {
		herdAlertTicks--
	}

	deerOneCaught := wolf.Activity == "feeding" &&
		wolf.TargetID == "deer-1"

	deerTwoCaught := wolf.Activity == "feeding" &&
		wolf.TargetID == "deer-2"

	targetOneX := routeOneX
	targetOneZ := routeOneZ
	deerOneFleeing := false

	if !deerOneCaught {
		targetOneX, targetOneZ, deerOneFleeing =
			fleeFromWolf("deer-1", routeOneX, routeOneZ)
	}

	targetTwoX := routeTwoX
	targetTwoZ := routeTwoZ
	deerTwoFleeing := false

	if !deerTwoCaught {
		targetTwoX, targetTwoZ, deerTwoFleeing =
			fleeFromWolf("deer-2", routeTwoX, routeTwoZ)
	}

	deerOneStep := 0.09
	deerOne.Activity = routeOneActivity

	if !deerOne.Alive {
		deerOneStep = 0.0
		deerOne.Activity = "dead"
	} else if deerOneCaught {
		deerOneStep = 0.0
		deerOne.Activity = "caught"
	} else if deerOneFleeing {
		deerOneStep = 0.21
		deerOne.Activity = "fleeing"
	}

	deerOne.X, deerOne.Z = moveToward(
		deerOne.X,
		deerOne.Z,
		targetOneX,
		targetOneZ,
		deerOneStep,
	)

	deerTwoStep := 0.09
	deerTwo.Activity = routeTwoActivity

	if !deerTwo.Alive {
		deerTwoStep = 0.0
		deerTwo.Activity = "dead"
	} else if deerTwoCaught {
		deerTwoStep = 0.0
		deerTwo.Activity = "caught"
	} else if deerTwoFleeing {
		deerTwoStep = 0.21
		deerTwo.Activity = "fleeing"
	}

	deerTwo.X, deerTwo.Z = moveToward(
		deerTwo.X,
		deerTwo.Z,
		targetTwoX,
		targetTwoZ,
		deerTwoStep,
	)

	deerStates["deer-1"] = deerOne
	deerStates["deer-2"] = deerTwo

	for index := range meadowFood {
		meadowFood[index] = clamp(
			meadowFood[index]+seasonalRegrowth(),
			0.0,
			1.0,
		)
	}

	if deerOne.Alive {
		updateDeerState("deer-1", deerOne.Activity, meadowOne)
	}

	if deerTwo.Alive {
		updateDeerState("deer-2", deerTwo.Activity, meadowTwo)
	}

	if ecosystemBalance() >= balanceGoal && len(tendedMeadows) >= 2 {
		balanceStreakTicks++
		seasonBalanceTicks++
	} else {
		balanceStreakTicks = 0
	}
}
