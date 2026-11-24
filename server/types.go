package main

type Animal struct {
	ID       string  `json:"id"`
	Species  string  `json:"species"`
	X        float64 `json:"x"`
	Z        float64 `json:"z"`
	Activity string  `json:"activity"`
	Hunger   float64 `json:"hunger"`
}

type Snapshot struct {
	Type              string    `json:"type"`
	Tick              uint64    `json:"tick"`
	Animals           []Animal  `json:"animals"`
	ReseedCooldown    uint64    `json:"reseedCooldown"`
	ReseedsRemaining  uint64    `json:"reseedsRemaining"`
	Balance           float64   `json:"balance"`
	BalanceStreak     uint64    `json:"balanceStreak"`
	Season            string    `json:"season"`
	SeasonsBalanced   uint64    `json:"seasonsBalanced"`
	GoalComplete      bool      `json:"goalComplete"`
	MeadowFood        []float64 `json:"meadowFood"`
	WolfCallCooldown  uint64    `json:"wolfCallCooldown"`
	SeasonEvent       string    `json:"seasonEvent"`
	SeasonHint        string    `json:"seasonHint"`
	SeasonResult      string    `json:"seasonResult"`
	SeasonReason      string    `json:"seasonReason"`
	SeasonReportTicks uint64    `json:"seasonReportTicks"`
	Director          string    `json:"director"`
	MeadowsTended     int       `json:"meadowsTended"`
}

type PlayerCommand struct {
	Type   string `json:"type"`
	Meadow int    `json:"meadow"`
	Delta  int    `json:"delta"`
}

type MeadowPoint struct {
	X float64
	Z float64
}

type WolfState struct {
	X         float64
	Z         float64
	Hunger    float64
	Activity  string
	FeedTicks uint64
	RestTicks uint64
	TargetID  string
}

type DeerState struct {
	X             float64
	Z             float64
	Activity      string
	Alive         bool
	RespawnTicks  uint64
	SafeTicks     uint64
	DecisionTicks uint64
	RestTicks     uint64
	GrazingTicks  uint64
	MeadowIndex   int
}

type FleeTarget struct {
	X float64
	Z float64
}
