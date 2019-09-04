extensions[array]

breed[voters voter]

voters-own[
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
  total-advantage
]

;;;;; SETUP PROCEDURES ;;;;;
to setup
  clear-all
  reset-ticks
  ; Create Axis on patches
  ask patches with [ pxcor = 0  or pycor = 0 ] [
    set pcolor white
  ]

  spawn-voters

  ; Initialize the social policy vector
  set social-policy-vector n-values number-of-issues [ 0 ]
  ask voters [
    set counted-in-last-poll? false
  ]
  ask patch 0 0 [
    ; Initialize poll turtle
    sprout 1 [
      set color yellow
      set shape "star"
      set size 3
      set hidden? true
      set poll-turtle self
    ]
    ;Initialize Social Policy Turtle
    sprout 1 [
      set color green
      set shape "star"
      set size 3
      set social-policy-turtle self
    ]
  ]
  ; No polls have occured yet, set poll to [].
  ; When poll is [], the poll vector will be hidden from the screen
  set poll []
  refresh
end

; Spawns in voters according to a utility distribution
to spawn-voters
  if utility-distribution = "Indifferent Majority vs. Passionate Minority"[
    spawn-voters-majority-vs-minority
    stop
  ]
  create-voters number-of-voters [
    set color violet
    set strategic? random-float 1 < proportion-of-strategic-voters
    ifelse strategic? [
      set color pink
    ][
      set color violet
    ]
    set-utilities
  ]
end

; Spawns voters for the majority vs. minority distribution
; The Majority will have a mean utility on the zero axis of -.05, while the Minority will have a mean utility on the zero axis of .8
; Therefore, the majority is slightly against issue 0 passing, while minority is heavily biased for the issue passing.
to spawn-voters-majority-vs-minority
  ; Record the total utility on the 0-axis
  let utility-sum-0 0
  ; Written Iteratively to keep track the total utility
  while [count voters != number-of-voters][
    create-voters 1 [

      ; Set strategic?
      set strategic? random-float 1 < proportion-of-strategic-voters
      ifelse strategic? [
        set color pink
      ][
        set color violet
      ]

      ; Assigns agent to majority or minority
      ; If the total utility on the 0 axis is below minority power, then the agent spawned will be part of the minority.
      ; Otherwise it will be part of the majority.
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

; Assigns the voters utilities according to the current utility distribution
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

; Moves voters and poll to their locations based of their utilities and poll results, respectively
to refresh
  clear-drawing

  ; Ensures the x-axis and y-axis are represented in the social policy vector.
  if x-axis >= length social-policy-vector [
    set x-axis 0
  ]
  if y-axis >= length social-policy-vector [
    set y-axis 0
  ]
  ; Move voters to represent their utilities
  ask voters [
    set xcor item x-axis utilities * max-pxcor
    set ycor item y-axis utilities * max-pycor
  ]

  ; If a poll exists, move the poll to represent the result
  ask poll-turtle[
    move-to-poll
  ]

  ; Move the social policy turtle to represent the result
  ask social-policy-turtle[
    move-to-result
  ]

  if social-policy-vector != n-values number-of-issues [ 0 ] [show-winners]
end

to go
  ifelse QV? [ vote-QV ][ vote-1p1v ]
end

; Called by the Vote Button, executes the voting procedure for QV
to vote-QV
  ; Ask voters not attached to a party turtle to vote
  ask voters[
    calculate-preferred-votes-QV
  ]

  ; sets social policy vector to be equal to the sum of all voting vectors
  set social-policy-vector n-values length social-policy-vector [0]
  foreach [votes] of voters [v -> (set social-policy-vector
    (map [[b c] -> b + c] v social-policy-vector))]
  refresh
  tick
end

; Called by the Vote Button, executes the voting procedure for 1p1v
to vote-1p1v
  set social-policy-vector n-values length social-policy-vector [0]

  ; Each Voter will cast 1 if utility is greater than 0 for an issue, -1 other wise
  foreach [utilities] of voters [
    u -> (
      set social-policy-vector (map
      [[b c] -> (b / abs b) + c]
      u social-policy-vector
    ))
  ]
  refresh
  tick
end


to calculate-preferred-votes-QV
  (ifelse strategic? and poll != [] and votes != 0
    [
      vote-strategic
    ]
    [
      vote-truthful
    ]
  )
end

; For the two issues that are shown on the grid, color the quadrant green if the outcome corresponding with it has the same sign.
to show-winners
  ask patches with [pxcor != 0  and  pycor != 0]  [set pcolor black]

  ; Find whether or not the sum of votes on x and y axises were positive or negative
  let x-sign (item x-axis social-policy-vector) / abs (item x-axis social-policy-vector)
  let y-sign (item y-axis social-policy-vector) / abs (item y-axis social-policy-vector)

  ; Set the appropriate quadrant green
  ask patches with [pxcor * x-sign >= 1 and pycor * y-sign >= 1]
  [set pcolor green - 3]
end

to move-to-result
  let next-xcor item x-axis social-policy-vector
  let next-ycor item y-axis social-policy-vector
  set xcor ifelse-value abs next-xcor > max-pxcor [(max-pxcor - 1) * next-xcor / abs next-xcor] [next-xcor]
  set ycor ifelse-value abs next-ycor > max-pycor [(max-pycor - 1) * next-ycor / abs next-ycor] [next-ycor]
end

to move-to-poll
  ifelse poll != []
    [set hidden? false
      let poll-patch patch
      ifelse-value (abs item x-axis poll) < max-pxcor [item x-axis poll] [(max-pxcor - 1) / item x-axis poll * abs item x-axis poll]
      ifelse-value (abs item y-axis poll) < max-pxcor [item y-axis poll] [(max-pycor - 1) / item y-axis poll * abs item y-axis poll]
      move-to poll-patch
  ]
  [
    set hidden? true
  ]
end

; Sets votes to be a multiple of utilities
to vote-truthful
  let j sqrt (1 / sum map [u -> u ^ 2] utilities)
  set votes map[u -> u * j] utilities
end

to vote-strategic
  let estimated-outcome poll

  ; If the agent was not counted in the last poll, add its votes to the poll
  if not counted-in-last-poll? [
    set estimated-outcome (map [[a b] -> a + b] estimated-outcome votes)
  ]

  ; Calculate number of votes by using the polling data to guess the marginal pivotality
  ; See "Calculating pivotality from polling" in Notion for more details
  set votes (map [[e-o u] -> .5 * psi-prime(e-o) * u] estimated-outcome utilities)

  let sum-of-votes^2 sum map [x -> x ^ 2] votes

  ; If all inputs in estimated-outcome are far from 0, psi-prime will output 0 as a result of floating point precision, and cause a divide by zero error.
  ; When this occurs, the voter should vote based on his utilities, knowing that either way, his vote will most likely not matter.
  ; Since votes do not carry over between elections in this scenario, the voter has no reason to not vote.
  ifelse sum-of-votes^2 != 0
  [
    ; Normalize Strategic Votes to 1
    let strategic-votes map [ x -> x / sqrt sum-of-votes^2 ] votes
  ]
  [
    vote-truthful
  ]
end

; Derivative of the payoff function. See "Calculating pivotality from polling" in Notion for more details
; The constants are as follows:
; delta is approximately the value in which psi(x) = sgn(x)
; b is a constant to adjust the graph so psi(delta) approximately equals sgn(x) at small values
to-report psi-prime[x]
  let delta 10
  let b 4
  report ifelse-value abs x > 50 * delta
  [0]
  [(2 * b * e ^ ( - b * x / delta)) / (delta * (1 + e ^ (- b * x / delta)) ^ 2)] ; This is a derivative of a sigmoid.
end

; Takes a random sample of agent's truthful vote, and saves the result in the poll vector
; Colluding groups do not affect polls
to take-poll
  let polled-agentset n-of (poll-response-rate * count voters) voters
  ask polled-agentset[
    calculate-preferred-votes-QV
    set counted-in-last-poll? true
  ]

  ask voters[
    if (not member? self polled-agentset) [
      set counted-in-last-poll? false
    ]
  ]
  set poll n-values length social-policy-vector [0]
  foreach [votes] of polled-agentset [
    a -> set poll (map [[b c] -> b + c] a poll)
  ]
  refresh
end

; Reporter for monitor
to-report poll-results
  ifelse poll != []
  [report map [x -> precision x 2] poll]
  [report "NO POLL ACTIVE"]
end

; Utility gain reporter for monitor
to-report total-utility-gain
  let index 0

  let sum-utilities n-values length social-policy-vector [0]
  foreach [utilities] of voters [list-u -> set sum-utilities (map [[s u] -> s + u] sum-utilities list-u)]
  let total-utility (map [[spv u] -> (ifelse-value
    spv = 0 [0]
    spv > 0 [u]
    spv < 0 [-1 * u]
  )] social-policy-vector sum-utilities)

  report total-utility
end

; Function for deleting voters
to delete-voters
    ask patch mouse-xcor mouse-ycor [
      ask voters in-radius 4 [die]
  ]
end

to-report maximal-utility?
  report not member? false map [x -> x > 0] total-utility-gain
end
@#$#@#$#@
GRAPHICS-WINDOW
248
12
711
476
-1
-1
7.0
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
0
0
1
ticks
30.0

SLIDER
0
15
219
48
number-of-voters
number-of-voters
0
10000
2000.0
100
1
voters
HORIZONTAL

SLIDER
0
48
219
81
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
82
219
115
number-of-issues
number-of-issues
2
10
10.0
1
1
Issues
HORIZONTAL

BUTTON
0
196
102
248
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
249
218
283
Vote!
ifelse QV? [vote-QV][vote-1p1v]
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
196
219
248
Refresh
refresh\n
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
715
11
887
44
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
715
48
887
81
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
715
185
888
219
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
715
220
887
253
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
284
103
317
QV?
QV?
0
1
-1000

BUTTON
105
284
218
318
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
318
218
352
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
716
341
1030
386
Social Policy Vector
map [x -> precision x 2]social-policy-vector
2
1
11

MONITOR
715
137
888
182
Poll Results
poll-results
17
1
11

MONITOR
716
293
814
338
Maximal Utility?
maximal-utility?
17
1
11

BUTTON
715
255
888
289
Clear Poll
set poll []\nask voters[\n    set counted-in-last-poll? false\n  ]
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
744
93
851
127
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
116
243
161
utility-distribution
utility-distribution
"Normal mean = 0" "Normal mean != 0" "Bimodal one direction" "Bimodal all directions" "Indifferent Majority vs. Passionate Minority"
4

TEXTBOX
905
10
1055
80
The yellow star represents the polling vector.\nThe green \nstar represents the votes vector\n
11
115.0
1

SLIDER
0
162
218
195
minority-power
minority-power
0
100
100.0
10
1
NIL
HORIZONTAL

MONITOR
716
387
1031
432
Utility Gain
map [x -> precision x 2] total-utility-gain
2
1
11

@#$#@#$#@
## WHAT IS IT?

This a model of Quadratic Voting, otherwise known as QV. QV has the following properties:

  * Each Voting Agent is allocated an equal amount of "Voice Credits", which may be used to purchase votes. 
  * During each election, there exists a number of referenda can to vote on. Each referendum can be either be voted for, or against. 
  * A Voting Agent may buy x votes for or against an referendum, by spending x<sup>2</sup> voice credits.

For example, if each agent has 100 voice credits, it may be inclined to spend all 100 voice credits on 10 vote for a single referendum, if it only cares about that specific referendum. If an agent wishes to split his 100 voice credits on 4 different referenda, he can spend 25 voice credits on each, gaining 5 votes for each referenda.  

## HOW IT WORKS 

How an agent votes is affected by their utility value for each issue. The Utility value is how much the agent will gain if the issue passes. (If it is negative, the agent will lose if the issue passes.) This may be represented in real life by how much the issue affects them, for example, a gay couple will have a higher utility value on the issue of gay marriage, as opposed to a straight couple, who are simply supporters of gay marriage, but it does not directly affect them.

Agents can be grouped into the following two categories:

  * Truthful Voters (Marked by Purple Agents)
  * Strategic Voters (Marked by Pink Agents)

Each of the categories of voters follow different rules when voting.

Truthful voters will map their utilites of each issue to votes, so their votes are proportional to their utilities. 

Strategic Voters will act like Truthful voters, unless a poll has been taken. If a poll has been taken, they will multiply each of their Truthful Votes by a calculated "marginal pivotality", which is an estimate on how likely the agent is to flip the outcome in their favor.  The marginal pivotality is calculated from the poll results. If the calculated marginal pivotality is extremely close to zero, a strategic voter will vote like the truthful voter.


## HOW TO USE IT

Before pressing setup(hotkey: s), set the number of voters, proportion of strategic voters, and the number of issues to vote on. 

After pressing setup, a number of voting agents will spawn.  Their utility will be represented by their position on the view. You can change which issue will be on the view, by changing the sliders "x-axis and y-axis", then pressing refresh(hotkey: r).

Press vote(hotkey: v) to have the agents vote.  The quadrant which won the vote will turn green, and a green star will appear to show the results of the vote.  The closer the star is to the white axis, the closer the vote was!

Some additional options are noted in "Things to try"

## THINGS TO NOTICE

///Don't really know what to put here that won't be on Things to Try

## THINGS TO TRY

Try changing the utility distribution.  Notice that the in the Minority v. Majority distribution the minority will likely win if there are more issues.  Can you guess why? In the Normal mean != 0 distribution there isn't much a difference between the strategic voters and the truthful voters.  Why is that?

Flipping the QV? switch will toggle the model between QV and one person one vote (1p1v).  Observe the differences between 1p1v and QV, especially in the Minority vs. Majority scenario. 

Turn up the proportion of strategic voters to 1, increase the percentage of the population polled, and press "Poll and Vote" repeatedly. Sometimes the results will oscillate between several different outcomes.  The Yellow star represents the result of the poll. 


## EXTENDING THE MODEL

QV may be suspectable to misinformation of ones own utilities, since votes spent on one issue will mean they aren't spent on another.  Can you implement an agent that can influence voters, and change how they percieve their utilities?

## NETLOGO FEATURES

This model extensively uses the "map" command with multiple array inputs, since the position in a list of utilities or results matters. A challenge when making this model was the readbility as a result of this.

## RELATED MODELS

See Quadratic Voting with Collusion

## CREDITS AND REFERENCES

You can find more information here:
https://www.notion.so/qvoting/Home-5664c87e234a4684adc862d1448dcc77
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
NetLogo 6.1.0
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
  <experiment name="converge-portion-of-strategic-vote" repetitions="1" runMetricsEveryStep="true">
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
  <experiment name="QV-Collusion" repetitions="500" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>vote-QV</go>
    <timeLimit steps="70"/>
    <metric>[shapley-value] of party-turtles</metric>
    <metric>mean [count link-neighbors] of party-turtles</metric>
    <metric>[count link-neighbors] of party-turtles</metric>
    <metric>count party-turtles</metric>
    <metric>total-utility-gain</metric>
    <metric>length map [x -&gt; x &gt; 0] total-utility-gain</metric>
    <enumeratedValueSet variable="vote-portion-strategic">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-voters">
      <value value="10000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="proportion-of-strategic-voters">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="party-turtles-created-per-cycle">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="QV?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-issues">
      <value value="2"/>
      <value value="5"/>
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="utility-distribution">
      <value value="&quot;Normal mean = 0&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="collusion-growth">
      <value value="1"/>
      <value value="5"/>
      <value value="10"/>
      <value value="100"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="QV-Collusion-test" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>vote-QV</go>
    <timeLimit steps="70"/>
    <metric>[shapley-value] of party-turtles</metric>
    <metric>mean [count link-neighbors] of party-turtles</metric>
    <metric>[count link-neighbors] of party-turtles</metric>
    <metric>count party-turtles</metric>
    <metric>total-utility-gain</metric>
    <metric>length map [x -&gt; x &gt; 0] total-utility-gain</metric>
    <enumeratedValueSet variable="vote-portion-strategic">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-voters">
      <value value="10000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="proportion-of-strategic-voters">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="party-turtles-created-per-cycle">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="QV?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-issues">
      <value value="2"/>
      <value value="5"/>
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="utility-distribution">
      <value value="&quot;Normal mean = 0&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="collusion-growth">
      <value value="1"/>
      <value value="5"/>
      <value value="10"/>
      <value value="100"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="QV-Collusion-Betray" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>count turtles</metric>
    <enumeratedValueSet variable="vote-portion-strategic">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-voters">
      <value value="200"/>
    </enumeratedValueSet>
    <steppedValueSet variable="proportion-cooperate" first="0.2" step="0.2" last="0.8"/>
    <enumeratedValueSet variable="proportion-of-strategic-voters">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-issues">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="poll-response-rate">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="colluding-turtles-created">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="utility-distribution">
      <value value="&quot;Normal mean = 0&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="collusion-growth">
      <value value="5"/>
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
