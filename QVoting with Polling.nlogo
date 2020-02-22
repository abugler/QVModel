; TODO
; - change spawn-voters-majority-vs-minority to be clearer and more intuitive
; - if needed, change lists of utilities to arrays for performance reasons
; -  think about changing psi-prime to round to zero earlier. Real people would not have such precision

__includes ["utils.nls"]

breed[voters voter]
breed[influencers influencer]

voters-own [
  utilities
  votes
  strategic?
  counted-in-last-poll?
]

globals[
  social-policy-vector
  social-policy-turtle
  poll
  results
  poll-turtle
  voice-credits
]


;*********************************************************************
;************************* Setup Code **************************
;*********************************************************************

to setup
  clear-all
  reset-ticks
  ; Create Axis
  ask patches with [pxcor = 0  or pycor = 0] [set pcolor white]

  spawn-voters

  ; Initialize the social policy vector
  set social-policy-vector n-values number-of-issues [0]

  ask voters [
    set counted-in-last-poll? false
  ]

  ; Initialize poll turtle
  ask patch 0 0 [
    sprout 1 [
      set color yellow
      set shape "star"
      set size 3
      set hidden? true
      set poll-turtle self
      set label "Poll"
    ]
    sprout 1 [
      set color green
      set shape "star"
      set size 3
      set social-policy-turtle self
      set label "Vote Outcome"
    ]
  ]
  set voice-credits 1
  set poll nobody
  refresh-viz
end

to spawn-voters
  (ifelse
    utility-distribution = "Indifferent Majority vs. Passionate Minority" [spawn-voters-majority-vs-minority]
    utility-distribution = "Prop8 mean>0" [create-voters-with-prop8-utility-dist]
    [  ; default option
    create-voters number-of-voters [
      set color violet
      set strategic? random-float 1 < proportion-of-strategic-voters

      ifelse strategic? [
        set color 115 + 20 * vote-portion-strategic
      ] [
        set color violet
      ]
      set-utilities
    ]
  ])
end

to spawn-voters-majority-vs-minority
  let utility-sum-0 0
    while [count voters != number-of-voters][
      create-voters 1 [
        set strategic? random-float 1 < proportion-of-strategic-voters
        ifelse strategic? [set color 115 + 20 * vote-portion-strategic][set color violet]
        ifelse utility-sum-0 < minority-power [
          set utilities n-values (number-of-issues - 1) [random-normal 0 .1]
          set utilities fput random-normal .8 .05 utilities]
        [
          set utilities n-values (number-of-issues - 1) [random-normal 0 .3]
          set utilities fput random-normal -.05 .05 utilities
        ]
        set utility-sum-0 utility-sum-0 + item 0 utilities
      ]
    ]
end

to create-voters-with-prop8-utility-dist
  ; This calibration is based off of sections 2.1 and 2.4 in Chandar and Weyl 2019
  ; utility units here are in units of $10k

  create-voters number-of-voters [
    set utilities n-values (number-of-issues - 1) [random-normal 0 .1] ; set utilities on all other issues
    set strategic? random-float 1 < proportion-of-strategic-voters
    ifelse strategic? [set color 115 + 20 * vote-portion-strategic][set color violet]

    let random-num random-float 1
    (ifelse
      random-num < 0.007 [ ; This is the portion of the population that is LGBT and in a relationship
        set utilities fput (.1 + random-float .9) utilities  ; .02 and .18 both * 5 to make these utilities comparable to utilities on other issues)
      ]
      random-num < 0.04 [ ; This the portion of the population that is LGBT and in a relationship
        set utilities fput (0.025 + random-float .175) utilities
      ]
      random-num < .48 [ ; This is the % of the non-LGBT population that supported gay marriage
        set utilities fput (random-float .1) utilities
      ]
      [ ; the remaining % of the population opposed gay marriage
        set utilities fput (random-float -.1) utilities
      ]
    )
  ]
end

to set-utilities
  (ifelse utility-distribution = "Normal mean = 0" [
    set utilities n-values number-of-issues [random-normal 0 .2]
    ]
    utility-distribution = "Normal mean != 0" [
      set utilities n-values number-of-issues [random-normal .2 .2]
    ]
    utility-distribution = "Bimodal one direction"[
      set utilities n-values (number-of-issues - 1) [random-normal 0 .2]
      ifelse random-float  1 > .5 [
        set utilities fput random-normal .3 .1 utilities
      ][
        set utilities fput random-normal -.3 .1 utilities
      ]
    ]
    utility-distribution = "Bimodal all directions"[
      ifelse random-float 1 > .5[
        set utilities n-values number-of-issues [random-normal .3 .1]
      ][
        set utilities n-values number-of-issues [random-normal -.3 .1]
      ]
    ]
  )
end




;************************************************************************
;************************* Voting & Polling Code ************************
;************************************************************************

to vote
  ifelse QV? [
    vote-QV
  ] [
    vote-1p1v
  ]
end
; Called by the Vote Button, executes the voting procedure for QV
to vote-QV
  reset-social-policty-vector
  ask voters [
    calculate-preferred-votes-QV
    set social-policy-vector (add-lists social-policy-vector votes)  ; add each persons votes to the social-policy vector
  ]
  tick
  refresh-viz
end

; Called by the Vote Button, executes the voting procedure for 1p1v
to vote-1p1v
  reset-social-policty-vector
  ask voters [
    set votes map [u -> sign-of u] utilities
    set social-policy-vector (add-lists social-policy-vector votes)
  ]
  tick
  refresh-viz
end


to calculate-preferred-votes-QV
  ; If the agent is strategic, the agent will take the information from the last poll, and make a decision based off it.
  ; The utility based vote is used in the calculation, so first that must be calculated.
  ifelse strategic? and poll != nobody and votes != 0 [
    vote-strategic
  ] [
    vote-truthful
  ]
end

to reset-social-policty-vector
  set social-policy-vector n-values length social-policy-vector [0]
end


; Sets votes to be a multiple of utilities
to vote-truthful
  let vc-per-u sqrt (voice-credits / sum map [u -> u ^ 2] utilities)  ; calculate voice credits per unit of utility given this voter's utilities
  set votes map[u -> u * vc-per-u] utilities
end

to vote-strategic
  let estimated-outcome poll

  ; If the agent was not counted in the last poll, add its votes to the poll
  if not counted-in-last-poll? [
    set estimated-outcome  (add-lists estimated-outcome votes)
  ]

  ; Calculate number of votes by using the polling data to guess the marginal pivotality
  ; See "Calculating pivotality from polling" in Notion for more details
  set votes (map [[e-o u] -> .5 * psi-prime(e-o) * u] estimated-outcome utilities)

  let sum-of-votes^2 sum map [x -> x ^ 2] votes

  ; A current bug in this algorithm is that if all inputs in estimated-outcome are far from 0, psi-prime will output 0 as a result of floating point precision, and cause a divide by zero error.
  ; When this occurs, the voter should vote based on his utilities, knowing that either way, his vote will most likely not matter.
  ; Since votes do not carry over between elections in this scenario, the voter has no reason to not vote.
  ifelse sum-of-votes^2 != 0 [
    ; Normalize Strategic Votes to 1
    let strategic-votes map [x -> (x / sqrt sum-of-votes^2) * voice-credits] votes
    ; Alias vote-portion-strategic to a, to shorten lines
    let a vote-portion-strategic
    vote-truthful
    ; The votes vector cast is a combination of strategic votes and truthful votes.
    ; a denotes the portion of the vote that shall be strategic.
    set votes (map [[v-t v-s] -> a * v-s + (1 - a) * v-t] votes strategic-votes)
    set votes map [x -> x / sqrt sum map [v -> v ^ 2] votes] votes  ; renormalize votes
  ] [
    vote-truthful
  ]
end

; Derivative of the payoff function. See "Calculating pivotality from polling" in Notion for more details
; The constants are as follows:
; delta is approximately the value in which psi(x) = sgn(x)
; b is a constant to adjust the graph so psi(delta) ~ sgn(x) at small values
to-report psi-prime [x]
  let delta .1
  let b 4
  report ifelse-value (abs x) > (50 * delta) [
    0
  ] [
    (2 * b * e ^ ( - b * x / delta)) / (delta * (1 + e ^ (- b * x / delta)) ^ 2)
  ]
end

; Takes a random sample of agent's vote, and saves the result in the poll vector. They vote in the poll as they would in the
; real election. i.e. if they are strategic and there is already an existing poll, they take that information into account.
; Otherwise, they vote Truthfully.
to take-poll
  ask voters [set counted-in-last-poll? false]

  let polled-agentset n-of (poll-response-rate * count voters) voters
  ask polled-agentset[
    calculate-preferred-votes-QV
    set counted-in-last-poll? true
  ]

  set poll n-values length social-policy-vector [0]
  ask polled-agentset [
    set poll (add-lists poll votes)
  ]
  ;foreach [votes] of polled-agentset [a -> set poll (map [[b c] -> b + c] a poll)]
  refresh-viz
end

; Reporter for monitor
to-report poll-results
  ifelse poll != nobody
  [report map [x -> precision x 2] poll]
  [report "NO POLL ACTIVE"]
end


;*********************************************************************
;************************* Visualization code **************************
;*********************************************************************

; For the two issues that are shown on the grid, color the quadrant green if the outcome corresponding with it has the same sign.
to show-winners
  ask patches with [pxcor != 0  and  pycor != 0]  [set pcolor black]
  let x-sign sign-of (item x-axis social-policy-vector)
  let y-sign sign-of (item y-axis social-policy-vector)
  ask patches with [pxcor != 0  and pycor != 0 and pxcor * x-sign >= 1 and pycor * y-sign >= 1]
  [set pcolor green - 3]
end

; reports the patch that poll turtle should be on, based of the last poll
to-report poll-patch
  report patch
  ifelse-value (abs item x-axis poll) < max-pxcor [item x-axis poll] [(max-pxcor - 1) / item x-axis poll * abs item x-axis poll]
  ifelse-value (abs item y-axis poll) < max-pxcor [item y-axis poll] [(max-pycor - 1) / item y-axis poll * abs item y-axis poll]
end

; Moves voters and poll to their locations based of their utilities and poll results, respectively
to refresh-viz
  clear-drawing
  if x-axis >= length social-policy-vector [set x-axis 0]
  if y-axis >= length social-policy-vector [set y-axis 0]
  ask voters [
    set xcor item x-axis utilities * max-pxcor
    set ycor item y-axis utilities * max-pycor
  ]
  ask poll-turtle[
    ifelse poll = nobody [
      set hidden? true
    ] [
      set hidden? false
      move-to poll-patch
    ]
  ]

  ask social-policy-turtle[
    let next-xcor item x-axis social-policy-vector
    let next-ycor item y-axis social-policy-vector
    set xcor ifelse-value abs next-xcor > max-pxcor [(max-pxcor - 1) * sign-of next-xcor] [next-xcor]
    set ycor ifelse-value abs next-ycor > max-pycor [(max-pycor - 1) * sign-of next-ycor] [next-ycor]
  ]

  ; If it is not the first tick, show the winners on the grid
  if ticks != 0 [show-winners]
end


;*********************************************************************
;************************* Reporters **************************
;*********************************************************************

; Utility gain reporter for monitor
to-report total-payoff-per-issue
  let index 0

  let utilities-sum n-values length social-policy-vector [0]
  ask voters [
    set utilities-sum add-lists utilities-sum utilities
  ]

  let payoff (map [[spv u] -> (sign-of spv) * u] social-policy-vector utilities-sum)

  report payoff
end


to-report mean-utilities
  report map [i -> mean [item i utilities] of voters] range number-of-issues
end

to-report median-utilities
  report map [i -> median [item i utilities] of voters] range number-of-issues
end

to-report mean-median-same-sign-list
  report (map [[mn md] -> ifelse-value sign-of mn = sign-of md [1] [0]]
    mean-utilities median-utilities)
end


to-report add-lists [lst1 lst2]
  report (map [[l1 l2] -> l1 + l2] lst1 lst2)
end


; Function for deleting voters
to delete-voters
    ask patch mouse-xcor mouse-ycor [
      ask voters in-radius 4 [die]
  ]
end

to-report maximal-utility?
  report not member? false map [x -> x > 0] total-payoff-per-issue
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; These are entirely for behavior space experiments
to store-outcome
  set results fput social-policy-vector results
end

to-report has-converged?
  if ticks < 4 [report false]
  let current-outcome item 0 results
  let index 1
  while [index <= 3]
  [
    if member? false (map [[c-o r] -> abs (c-o - r) < .1] current-outcome (item index results)) [
    report false
  ]
    set index index + 1
  ]
  report true
end
@#$#@#$#@
GRAPHICS-WINDOW
292
10
813
532
-1
-1
7.9
1
10
1
1
1
0
1
1
1
-32
32
-32
32
1
1
1
ticks
30.0

SLIDER
0
10
219
43
number-of-voters
number-of-voters
11
10001
9361.0
10
1
NIL
HORIZONTAL

SLIDER
0
43
219
76
proportion-of-strategic-voters
proportion-of-strategic-voters
0
1
1.0
.01
1
NIL
HORIZONTAL

SLIDER
0
77
219
110
number-of-issues
number-of-issues
1
10
10.0
1
1
NIL
HORIZONTAL

BUTTON
0
191
102
243
Setup
setup\n
NIL
1
T
OBSERVER
NIL
S
NIL
NIL
1

BUTTON
0
281
218
315
Vote!
vote
NIL
1
T
OBSERVER
NIL
V
NIL
NIL
0

BUTTON
104
191
219
243
Refresh
refresh-viz\n
NIL
1
T
OBSERVER
NIL
R
NIL
NIL
0

SLIDER
832
12
1004
45
x-axis
x-axis
0
number-of-issues - 1
0.0
1
1
NIL
HORIZONTAL

SLIDER
833
50
1005
83
y-axis
y-axis
0
number-of-issues - 1
1.0
1
1
NIL
HORIZONTAL

BUTTON
833
187
1006
221
Conduct a poll!
take-poll
NIL
1
T
OBSERVER
NIL
P
NIL
NIL
0

SLIDER
833
222
1005
255
poll-response-rate
poll-response-rate
0
1
1.0
.01
1
NIL
HORIZONTAL

SWITCH
0
316
103
349
QV?
QV?
0
1
-1000

BUTTON
105
316
218
350
Toggle QV?
set QV? not QV?
NIL
1
T
OBSERVER
NIL
Q
NIL
NIL
0

BUTTON
0
350
218
384
Poll and Vote
take-poll\nifelse QV? [vote-QV][vote-1p1v]
NIL
1
T
OBSERVER
NIL
A
NIL
NIL
0

MONITOR
0
494
296
539
Social Policy Vector
map [x -> precision x 2] social-policy-vector
2
1
11

MONITOR
833
139
1006
184
Poll Results
poll-results
17
1
11

MONITOR
0
446
98
491
Maximal Utility?
maximal-utility?
17
1
11

BUTTON
833
257
1006
291
Clear Poll
set poll nobody\nask voters[\n    set counted-in-last-poll? false\n  ]
NIL
1
T
OBSERVER
NIL
C
NIL
NIL
0

BUTTON
862
95
969
129
Delete Voters
delete-voters
NIL
1
T
OBSERVER
NIL
D
NIL
NIL
1

CHOOSER
0
111
243
156
utility-distribution
utility-distribution
"Normal mean = 0" "Normal mean != 0" "Bimodal one direction" "Bimodal all directions" "Indifferent Majority vs. Passionate Minority" "Prop8 mean>0"
5

TEXTBOX
845
296
995
366
The yellow star represents the polling vector.\nThe green \nstar represents the votes vector\n
11
115.0
1

SLIDER
0
157
218
190
minority-power
minority-power
0
100
0.0
10
1
NIL
HORIZONTAL

MONITOR
0
540
307
585
Total Payoff Per Issue
map [x -> precision x 2] total-payoff-per-issue
2
1
11

SLIDER
0
245
219
278
vote-portion-strategic
vote-portion-strategic
0
1
0.0
.01
1
NIL
HORIZONTAL

PLOT
820
371
1020
521
Votes cast vs utility
utility of issue
votes cast on issue
-1.0
1.0
-1.0
1.0
true
false
"" "clear-plot"
PENS
"default" 1.0 2 -13345367 true "" "ask voters [plotxy item issue-num utilities item issue-num votes]"
"pen-1" 1.0 0 -7500403 true "" "plot-y-axis"
"pen-2" 1.0 0 -7500403 true "" "plot-x-axis"

SLIDER
823
525
983
558
issue-num
issue-num
0
number-of-issues - 1
0.0
1
1
NIL
HORIZONTAL

BUTTON
989
524
1101
557
NIL
update-plots
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

PLOT
1025
371
1225
521
Utilities vs Votes for one turtles
NIL
NIL
-1.0
1.0
-1.0
1.0
true
false
"" "clear-plot"
PENS
"default" 1.0 2 -16777216 true "" "if ticks > 0 [\nlet Us [utilities] of voter voter-num\nlet Vs [votes] of voter voter-num\n(foreach Us Vs [[u v] -> plotxy u v])\n]"
"pen-1" 1.0 0 -7500403 true "" "plot-x-axis"
"pen-2" 1.0 0 -7500403 true "" "plot-y-axis"
"pen-3" 1.0 2 -2674135 true "" "if ticks > 0 [\nlet Us [utilities] of voter 1\nlet Vs [votes] of voter 1\n(foreach Us Vs [[u v] -> plotxy u v])\n]"

INPUTBOX
1104
523
1253
583
voter-num
386.0
1
0
Number

BUTTON
24
398
133
431
setup & vote
setup\nvote
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

PLOT
1023
217
1223
367
histogram of votes on issue-num
NIL
NIL
-1.0
1.0
0.0
10.0
false
false
"set-plot-y-range 0 round number-of-voters / 5" ""
PENS
"default" 0.1 1 -16777216 true "" "histogram [item issue-num votes] of voters"
"pen-1" 1.0 0 -7500403 true "" "plot-y-axis"

@#$#@#$#@
## experiments
This repeated 100 times took less than 2 minutes
["number-of-voters" 11 51 101 501 1001 5001 10001]
["vote-portion-strategic" 0]
["proportion-of-strategic-voters" 1]
["minority-power" 0]
["y-axis" 1]
["x-axis" 0]
["QV?" false true]
["number-of-issues" 2 4 8]
["issue-num" 0]
["poll-response-rate" 1]
["utility-distribution" "Normal mean = 0"]

## WHAT IS IT?

(a general understanding of what the model is trying to show or explain)

## HOW IT WORKS

(what rules the agents use to create the overall behavior of the model)

## HOW TO USE IT

(how to use the model, including a description of each of the items in the Interface tab)

## THINGS TO NOTICE

(suggested things for the user to notice while running the model)

## THINGS TO TRY

(suggested things for the user to try to do (move sliders, switches, etc.) with the model)

## EXTENDING THE MODEL

(suggested things to add or change in the Code tab to make the model more complicated, detailed, accurate, etc.)

## NETLOGO FEATURES

(interesting or unusual features of NetLogo that the model uses, particularly in the Code tab; or where workarounds were needed for missing features)

## RELATED MODELS

(models in the NetLogo Models Library and elsewhere which are of related interest)

## CREDITS AND REFERENCES

(a reference to the model's URL on the web if it has one, as well as any other necessary credits, citations, and links)
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.1.1
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="PRR-and-PSV" repetitions="1000" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>take-poll
vote-QV</go>
    <timeLimit steps="1"/>
    <metric>total-utility-gain</metric>
    <metric>social-policy-vector</metric>
    <metric>poll</metric>
    <enumeratedValueSet variable="number-of-voters">
      <value value="1000"/>
    </enumeratedValueSet>
    <steppedValueSet variable="proportion-of-strategic-voters" first="0.1" step="0.1" last="1"/>
    <enumeratedValueSet variable="number-of-issues">
      <value value="2"/>
    </enumeratedValueSet>
    <steppedValueSet variable="poll-response-rate" first="0.1" step="0.1" last="1"/>
  </experiment>
  <experiment name="PRR-and-PSV-Control" repetitions="1000" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>take-poll
vote-QV</go>
    <timeLimit steps="1"/>
    <metric>total-utility-gain</metric>
    <metric>social-policy-vector</metric>
    <metric>poll</metric>
    <enumeratedValueSet variable="number-of-voters">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="proportion-of-strategic-voters">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-issues">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="poll-response-rate">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="does-polling-converge" repetitions="500" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>take-poll
set social-policy-vector poll</go>
    <timeLimit steps="50"/>
    <metric>poll</metric>
    <metric>total-utility-gain</metric>
    <metric>maximal-utility?</metric>
    <enumeratedValueSet variable="number-of-voters">
      <value value="1500"/>
    </enumeratedValueSet>
    <steppedValueSet variable="proportion-of-strategic-voters" first="0.1" step="0.2" last="0.9"/>
    <enumeratedValueSet variable="number-of-issues">
      <value value="2"/>
      <value value="5"/>
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="poll-response-rate">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="utility-distribution">
      <value value="&quot;Normal mean = 0&quot;"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="minority-vs-majority" repetitions="2000" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>vote-QV</go>
    <timeLimit steps="1"/>
    <metric>maximal-utility?</metric>
    <metric>social-policy-vector</metric>
    <metric>total-utility-gain</metric>
    <enumeratedValueSet variable="number-of-voters">
      <value value="1500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="proportion-of-strategic-voters">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="poll-memory">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="minority-power">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="QV?">
      <value value="true"/>
    </enumeratedValueSet>
    <steppedValueSet variable="number-of-issues" first="2" step="1" last="10"/>
    <enumeratedValueSet variable="poll-response-rate">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="utility-distribution">
      <value value="&quot;Indifferent Majority vs. Passionate Minority&quot;"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="converge-portion-of-strategic-vote" repetitions="1000" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>take-poll
set social-policy-vector poll</go>
    <timeLimit steps="50"/>
    <metric>poll</metric>
    <metric>total-utility-gain</metric>
    <steppedValueSet variable="vote-portion-strategic" first="0.1" step="0.2" last="0.9"/>
    <enumeratedValueSet variable="number-of-voters">
      <value value="1500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="proportion-of-strategic-voters">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="QV?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-issues">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="poll-response-rate">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="utility-distribution">
      <value value="&quot;Normal mean = 0&quot;"/>
      <value value="&quot;Normal mean != 0&quot;"/>
      <value value="&quot;Bimodal one direction&quot;"/>
      <value value="&quot;Bimodal all directions&quot;"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="non-strategic-voting" repetitions="1000" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>vote</go>
    <timeLimit steps="1"/>
    <metric>maximal-utility?</metric>
    <metric>total-payoff-per-issue</metric>
    <metric>mean-utilities</metric>
    <metric>median-utilities</metric>
    <metric>mean-median-same-sign-list</metric>
    <enumeratedValueSet variable="number-of-voters">
      <value value="11"/>
      <value value="51"/>
      <value value="101"/>
      <value value="501"/>
      <value value="1001"/>
      <value value="5001"/>
      <value value="10001"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="vote-portion-strategic">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="proportion-of-strategic-voters">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="minority-power">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="y-axis">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="x-axis">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="QV?">
      <value value="false"/>
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-issues">
      <value value="2"/>
      <value value="4"/>
      <value value="6"/>
      <value value="8"/>
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="issue-num">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="poll-response-rate">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="utility-distribution">
      <value value="&quot;Normal mean = 0&quot;"/>
      <value value="&quot;Prop8 mean&gt;0&quot;"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="non-strategic-voting (5 issues)" repetitions="1000" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>vote</go>
    <timeLimit steps="1"/>
    <metric>maximal-utility?</metric>
    <metric>total-payoff-per-issue</metric>
    <metric>mean-utilities</metric>
    <metric>median-utilities</metric>
    <metric>mean-median-same-sign-list</metric>
    <enumeratedValueSet variable="number-of-voters">
      <value value="11"/>
      <value value="51"/>
      <value value="101"/>
      <value value="501"/>
      <value value="1001"/>
      <value value="5001"/>
      <value value="10001"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="vote-portion-strategic">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="proportion-of-strategic-voters">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="minority-power">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="y-axis">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="x-axis">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="QV?">
      <value value="false"/>
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-issues">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="issue-num">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="poll-response-rate">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="utility-distribution">
      <value value="&quot;Prop8 mean&gt;0&quot;"/>
    </enumeratedValueSet>
  </experiment>
</experiments>
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
0
@#$#@#$#@
