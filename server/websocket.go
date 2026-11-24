package main

import (
	"encoding/json"
	"log"
	"net/http"
	"sync/atomic"
	"time"

	"github.com/gorilla/websocket"
)

var upgrader = websocket.Upgrader{
	CheckOrigin: func(r *http.Request) bool { return true },
}

func handleWebSocket(simulationTick *atomic.Uint64) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		conn, err := upgrader.Upgrade(w, r, nil)
		if err != nil {
			log.Println(err)
			return
		}
		defer conn.Close()

		done := make(chan struct{})
		go readCommands(conn, done)

		updateClock := time.NewTicker(100 * time.Millisecond)
		defer updateClock.Stop()
		for {
			select {
			case <-done:
				return
			case <-updateClock.C:
				if err := sendSnapshot(conn, simulationTick.Load()); err != nil {
					return
				}
			}
		}
	}
}

func readCommands(conn *websocket.Conn, done chan<- struct{}) {
	defer close(done)
	for {
		_, payload, err := conn.ReadMessage()
		if err != nil {
			return
		}

		var command PlayerCommand
		if json.Unmarshal(payload, &command) != nil {
			continue
		}

		stateMu.Lock()
		switch command.Type {
		case "reseed":
			if command.Meadow >= 0 && command.Meadow < len(meadowFood) && reseedCooldownTicks == 0 && reseedsThisSeason < reseedLimitPerSeason {
				meadowFood[command.Meadow] = clamp(meadowFood[command.Meadow]+0.45, 0.0, 1.0)
				reseedCooldownTicks = reseedCooldownDurationTicks
				reseedsThisSeason++
				tendedMeadows[command.Meadow] = true
			}
		case "scare_wolf":
			if wolfCallCooldown == 0 {
				wolfRetreatTicks = wolfCallDurationTicks
				wolfCallCooldown = wolfCallCooldownTicks
				wolf.Hunger = clamp(wolf.Hunger-0.12, 0.15, 1.0)
			}
		case "adjust_deer":
			adjustStewardPopulation("deer", command.Delta)
		case "adjust_wolf":
			adjustStewardPopulation("wolf", command.Delta)
		case "restart":
			resetSimulationState()
		}
		stateMu.Unlock()
	}
}

func sendSnapshot(conn *websocket.Conn, tick uint64) error {
	stateMu.RLock()
	deerOne := deerStates["deer-1"]
	deerTwo := deerStates["deer-2"]
	wolfSnapshot := wolf
	foodSnapshot := append([]float64(nil), meadowFood...)
	event, hint, _ := currentSeasonEvent()
	animals := []Animal{
		{ID: "deer-1", Species: "deer", X: deerOne.X, Z: deerOne.Z, Activity: deerOne.Activity, Hunger: hungerByDeer["deer-1"]},
		{ID: "deer-2", Species: "deer", X: deerTwo.X, Z: deerTwo.Z, Activity: deerTwo.Activity, Hunger: hungerByDeer["deer-2"]},
		{ID: "wolf-1", Species: "wolf", X: wolfSnapshot.X, Z: wolfSnapshot.Z, Activity: wolfSnapshot.Activity, Hunger: wolfSnapshot.Hunger},
	}

	for _, id := range []string{"deer-3", "deer-4", "deer-5", "deer-6"} {
		deer, exists := ambientDeerStates[id]
		if !exists {
			continue
		}
		activity := deer.Activity
		if _, retiring := retiringDeer[id]; retiring {
			activity = "dead"
		}
		animals = append(animals, Animal{ID: id, Species: "deer", X: deer.X, Z: deer.Z, Activity: activity})
	}

	// Always include the slot so a retired pack mate is removed client-side.
	animals = append(animals, Animal{ID: "wolf-2", Species: "wolf", X: packWolf.X, Z: packWolf.Z, Activity: packWolf.Activity, Hunger: packWolf.Hunger})

	snapshot := Snapshot{
		Type:              "snapshot",
		Tick:              tick,
		ReseedCooldown:    reseedCooldownTicks,
		ReseedsRemaining:  reseedLimitPerSeason - reseedsThisSeason,
		Balance:           ecosystemBalance(),
		BalanceStreak:     balanceStreakTicks,
		Season:            seasons[seasonIndex],
		SeasonsBalanced:   seasonsBalanced,
		GoalComplete:      seasonsBalanced >= seasonsToWin,
		MeadowFood:        foodSnapshot,
		WolfCallCooldown:  wolfCallCooldown,
		SeasonEvent:       event,
		SeasonHint:        hint,
		SeasonResult:      lastSeasonResult,
		SeasonReason:      lastSeasonReason,
		SeasonReportTicks: seasonReportTicks,
		Director:          directorStatus,
		MeadowsTended:     len(tendedMeadows),
		Animals:           animals,
	}
	stateMu.RUnlock()

	payload, err := json.Marshal(snapshot)
	if err != nil {
		return err
	}
	return conn.WriteMessage(websocket.TextMessage, payload)
}
