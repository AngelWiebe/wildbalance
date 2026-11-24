package main

import (
	"log"
	"net/http"
	"sync/atomic"
	"time"
)

func main() {
	var simulationTick atomic.Uint64
	simulationClock := time.NewTicker(100 * time.Millisecond)
	defer simulationClock.Stop()

	go func() {
		for range simulationClock.C {
			updateSimulation(simulationTick.Add(1))
		}
	}()

	http.HandleFunc("/ws", handleWebSocket(&simulationTick))
	log.Println("WildBalance server listening on http://localhost:8080/ws")
	log.Fatal(http.ListenAndServe("127.0.0.1:8080", nil))
}
