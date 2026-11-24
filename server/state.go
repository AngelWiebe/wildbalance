package main

import "sync"

var meadowRoute = []MeadowPoint{
	{X: -3.0, Z: -1.8},
	{X: -9.0, Z: -14.0},
	{X: -6.0, Z: 12.0},
	{X: -14.0, Z: 26.0},
	{X: -25.0, Z: -8.0},
	{X: -27.0, Z: 10.0},
	{X: -25.0, Z: 28.0},
	{X: -38.0, Z: 18.0},
}

const balanceGoal = 70.0
const balanceGoalTicks uint64 = 600
const seasonLengthTicks uint64 = 900
const seasonsToWin uint64 = 4
const grazingArrivalDistance = 0.65
const wolfCallDurationTicks uint64 = 80
const wolfCallCooldownTicks uint64 = 180
const reseedCooldownDurationTicks uint64 = 80
const directorReviewTicks uint64 = 50
const reseedLimitPerSeason uint64 = 3

var (
	stateMu                  sync.RWMutex
	reseedCooldownTicks      uint64
	reseedsThisSeason        uint64
	wolfCallCooldown         uint64
	wolfRetreatTicks         uint64
	balanceStreakTicks       uint64
	seasonBalanceTicks       uint64
	seasonsBalanced          uint64
	seasonIndex              int
	seasonTicks              uint64
	seasonReportTicks        uint64
	herdAlertTicks           uint64
	lastSeasonResult                = "KEEP THE ECOSYSTEM BALANCED"
	lastSeasonReason                = "Hold balance above 70% for 60 seconds."
	directorStatus                  = "DIRECTOR  •  observing the ecosystem"
	directorHuntThreshold           = 0.55
	directorWolfStep                = 0.30
	directorRespawnDelay     uint64 = 120
	directorDeerTarget              = 4
	directorWolfTarget              = 2
	stewardPopulationManaged        = false
	stewardDeerTarget               = 4
	stewardWolfTarget               = 2
	ambientDeerStates               = map[string]DeerState{}
	retiringDeer                    = map[string]uint64{}
	tendedMeadows                   = map[int]bool{}
	packWolf                        = WolfState{X: -9.5, Z: -7.0, Hunger: 0.55, Activity: "wandering"}
	seasons                         = []string{"SPRING", "SUMMER", "AUTUMN", "WINTER"}
	fleeTargets                     = map[string]FleeTarget{}
	hungerByDeer                    = map[string]float64{"deer-1": 0.35, "deer-2": 0.55}
	meadowFood                      = []float64{1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0}
	wolf                            = WolfState{X: -8.0, Z: -6.0, Hunger: 0.70, Activity: "wandering"}
	deerStates                      = map[string]DeerState{
		"deer-1": {X: -3.0, Z: -1.8, Activity: "walking", Alive: true, SafeTicks: 50, MeadowIndex: 0},
		"deer-2": {X: -6.0, Z: 12.0, Activity: "walking", Alive: true, SafeTicks: 50, MeadowIndex: 2},
	}
)

func resetSimulationState() {
	reseedCooldownTicks = 0
	reseedsThisSeason = 0
	wolfCallCooldown = 0
	wolfRetreatTicks = 0
	balanceStreakTicks = 0
	seasonBalanceTicks = 0
	seasonsBalanced = 0
	seasonIndex = 0
	seasonTicks = 0
	seasonReportTicks = 0
	herdAlertTicks = 0
	lastSeasonResult = "KEEP THE ECOSYSTEM BALANCED"
	lastSeasonReason = "Hold balance above 70% for 60 seconds."
	directorStatus = "DIRECTOR  •  observing the ecosystem"
	directorHuntThreshold = 0.55
	directorWolfStep = 0.30
	directorRespawnDelay = 120
	directorDeerTarget = 4
	directorWolfTarget = 2
	stewardPopulationManaged = false
	stewardDeerTarget = 4
	stewardWolfTarget = 2
	ambientDeerStates = map[string]DeerState{}
	retiringDeer = map[string]uint64{}
	tendedMeadows = map[int]bool{}
	packWolf = WolfState{X: -9.5, Z: -7.0, Hunger: 0.55, Activity: "wandering"}
	fleeTargets = map[string]FleeTarget{}
	hungerByDeer = map[string]float64{"deer-1": 0.35, "deer-2": 0.55}
	meadowFood = []float64{1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0}
	wolf = WolfState{X: -8.0, Z: -6.0, Hunger: 0.70, Activity: "wandering"}
	deerStates = map[string]DeerState{
		"deer-1": {X: -3.0, Z: -1.8, Activity: "walking", Alive: true, SafeTicks: 50, MeadowIndex: 0},
		"deer-2": {X: -6.0, Z: 12.0, Activity: "walking", Alive: true, SafeTicks: 50, MeadowIndex: 2},
	}
}
