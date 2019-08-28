extensions[array matrix]
breed[voters voter]
breed[colluding-turtles colluding-turtle]

voters-own[
  utilities
  votes
  strategic?
]

colluding-turtles-own[
  total-utility
  normalized-utility
  votes
  individual-votes ; individual votes is simply for bookkeeping
  advantage
]

globals[
  social-policy-vector
  social-policy-turtle
  results
  total-advantage
  issues
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
  set social-policy-vector array:from-list n-values number-of-issues [ 0 ]
  set issues range number-of-issues
  ask patch 0 0 [
    ;Initialize Social Policy Turtle
    sprout 1 [
      set color green
      set shape "star"
      set size 3
      set social-policy-turtle self
    ]
  ]
  refresh
end

; Spawns in voters according to a utility distribution
to spawn-voters
  create-voters number-of-voters[
    set color violet
  ]
  set-utilities
end

; Assigns voters utilities for the majority vs. minority distribution
; The Majority will have a mean utility on the zero axis of -.05, while the Minority will have a mean utility on the zero axis of .8
; Therefore, the majority is slightly against issue 0 passing, while minority is heavily biased for the issue passing.
to set-majority-vs-minority-utilities
  let utility-sum-0 0
  ask voters[
    ifelse utility-sum-0 < minority-power[
      set utilities n-values (number-of-issues - 1) [random-normal 0 .1]
      set utilities fput random-normal .8 .05 utilities
      set utility-sum-0 utility-sum-0 + item 0 utilities
    ][
      set utilities n-values (number-of-issues - 1) [random-normal 0 .3]
      set utilities fput random-normal -.05 .05 utilities
      set utility-sum-0 utility-sum-0 + item 0 utilities
    ]
  ]
end

; Assigns the voters utilities according to the current utility distribution
to set-utilities
  (ifelse utility-distribution = "Normal mean = 0" [
    ask voters[
      set utilities n-values number-of-issues [random-normal 0 .2]
    ]
    ]
    utility-distribution = "Normal mean != 0" [
      ask voters[
        set utilities n-values number-of-issues [random-normal .2 .2]]
    ]
    utility-distribution = "Bimodal one direction"[
      ask voters[
        set utilities n-values (number-of-issues - 1) [random-normal 0 .2]
        ifelse random-float  1 > .5 [
          set utilities fput random-normal .3 .1 utilities
        ][
          set utilities fput random-normal -.3 .1 utilities
        ]
      ]
    ]
      utility-distribution = "Bimodal all directions"[
        ask voters[
          ifelse random-float 1 > .5[
            set utilities n-values number-of-issues [random-normal .3 .1]
          ][
            set utilities n-values number-of-issues [random-normal -.3 .1]
          ]
        ]
      ]
      utility-distribution = "Indifferent Majority vs. Passionate Minority"[
        set-majority-vs-minority-utilities
      ]
  )
end

; Moves voters and party turtles to their locations based of their utilities
to refresh
  clear-drawing

  ; Ensures the x-axis and y-axis are represented in the social policy vector.
  if x-axis >= array:length social-policy-vector [
    set x-axis 0
  ]
  if y-axis >= array:length social-policy-vector [
    set y-axis 0
  ]
  ; Move voters to represent their utilities
  ask voters [
    set xcor item x-axis utilities * max-pxcor
    set ycor item y-axis utilities * max-pycor
  ]

  ; Move the social policy turtle to represent the result
  ask social-policy-turtle [
    move-to-result
  ]

  ; Move the party turtles to be the average of all its members positions
  ask colluding-turtles[
    set xcor mean [xcor] of link-neighbors
    set ycor mean [ycor] of link-neighbors
  ]

  ; If it is not the first tick, show the winners on the grid
  if ticks != 0 [show-winners]
end

to go
  ifelse QV? [ vote-QV ][ vote-1p1v ]
  tick
  refresh
end

; Called by the Vote Button, executes the voting procedure for QV
to vote-QV
  ; Ask voters not attached to a party turtle to vote
  ask voters with [not any? link-neighbors][
    vote-truthful
  ]

  ; Ask party turtles to assign their members' votes
  ask colluding-turtles [
    vote-collude
  ]

  ; Sum all advantages gained by the party turtles together
  set total-advantage  array:from-list n-values array:length social-policy-vector [0]
  foreach issues [i -> array:set social-policy-vector i sum [item i advantage] of colluding-turtles]

  ; sets social policy vector to be equal to the sum of all voting vectors
  foreach issues [i -> array:set social-policy-vector i sum [item i votes] of voters]
  collude
end

; Creates party turtles.  If a voter loses more than one dimension, it will create a party turtle.
; These turtles will connect to voters with the same utility signs as their "utility doctrine". (The zeros in the doctrine mean that the turtle has no preference)
; Party turtles require that the turtles linked to it must vote as stated in its doctrine. (For now, the doctrine requires that all voters will split their votes equally among these issues)
; This should cause the group to have a greater influence than the sum of the individual voters
to collude
  find-new-voters
  make-new-colluding-turtles
  ask colluding-turtles with [not any? link-neighbors] [die]
end

to make-new-colluding-turtles
  let social-policy-list array:to-list social-policy-vector

  ; Find losing voters, which are voters that have lost in more than one dimension, and are not already part of a group
  let lost-dimensions [ -> length filter [x -> x < 0] (map [[u spv] -> u * spv] utilities social-policy-list)]
  let losing-voters voters with [runresult lost-dimensions > 1 and not any? link-neighbors]
  let number-of-new-turtles min list colluding-turtles-created count losing-voters

  ask n-of number-of-new-turtles losing-voters [
    let won-election-vector (map [[u spv] -> u * spv > 0] utilities social-policy-list)
    hatch-colluding-turtles 1 [
      set color red
      set size 3
      set shape "turtle"
      create-link-with myself [set color yellow]
      ; Set Utility Doctrine to be the signs of the voter's utility, if the voter lost in that dimension.
      ; If the voter did not lose in that dimenion, then set to zero
      set total-utility normalize [utilities] of myself
      set normalized-utility total-utility
    ]
  ]
end

to find-new-voters
  ask colluding-turtles [
    ; Find voters that have agreeing utilities, and not already linked to
    let potential-colluder-set n-of collusion-growth voters
    ask potential-colluder-set [
      let asking-turtle myself
      let normal-utility matrix-normalize matrix:from-row-list (list utilities)

      ; If the voter is already apart of a colluding group...
      ifelse any? link-neighbors
      [
        let current-turtle one-of link-neighbors
        ; The following code checks if the vote total between the two colluding groups is more aligned if the agent switches or not.
        ; See the section "Averaged Colluding Groups" in Notion for details on how the vector math works.
        let current-turtle-utility-switch matrix:minus matrix:from-row-list (list [total-utility] of current-turtle) normal-utility
        let asking-turtle-utility-switch matrix:plus matrix:from-row-list (list [total-utility] of asking-turtle) normal-utility
        let asking-turtle-utility-stay matrix:from-row-list (list [normalized-utility] of asking-turtle)
        let current-turtle-utility-stay matrix:from-row-list (list [normalized-utility] of current-turtle)
        let is-switching-greater-aligned? (sum matrix:get-row (matrix:times-element-wise normal-utility
          (matrix:plus
            (matrix:times matrix-normalize current-turtle-utility-switch ([count link-neighbors] of current-turtle - 1))
            (matrix:times matrix-normalize asking-turtle-utility-switch ([count link-neighbors] of asking-turtle + 1))
            (matrix:times current-turtle-utility-stay  -1  [count link-neighbors] of current-turtle)
            (matrix:times asking-turtle-utility-stay  -1  [count link-neighbors] of asking-turtle))
          ) 0
        ) > 0

        if is-switching-greater-aligned? [
          ask my-links [die]
          create-link-with asking-turtle[set color yellow]
          ask asking-turtle [
            set total-utility matrix:get-row asking-turtle-utility-switch 0
            set normalized-utility normalize total-utility
          ]
          ask current-turtle [
            set total-utility matrix:get-row current-turtle-utility-switch 0
            set normalized-utility normalize total-utility
          ]
        ]
      ]
      ; If not...
      [
        ; The following code checks if the vote total of the group and the agent is more aligned with the agent if he joins or not.
        ; See the section "Averaged Colluding Groups" in Notion for details on how the vector math works.
        let votes-vector matrix:from-row-list (list votes)
        let asking-turtle-utility-decline matrix:from-row-list (list [normalized-utility] of asking-turtle)
        let asking-turtle-utility-join matrix:plus matrix:from-row-list (list [total-utility] of asking-turtle) normal-utility
        let is-switching-greater-aligned? (sum matrix:get-row (matrix:times-element-wise normal-utility
          (matrix:minus
            (matrix:times matrix-normalize asking-turtle-utility-join ([count link-neighbors] of asking-turtle + 1))
            votes-vector
            (matrix:times asking-turtle-utility-decline [count link-neighbors] of asking-turtle)
          )) 0
        ) > 0

        show votes
        show asking-turtle-utility-decline
        show asking-turtle-utility-join

        if is-switching-greater-aligned?[
          show "JOINED!"
          create-link-with asking-turtle[set color yellow]
          ask asking-turtle [
            set total-utility matrix:get-row asking-turtle-utility-join 0
            set normalized-utility normalize total-utility
          ]
        ]
      ]
    ]
  ]
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
end

; Party Turtle method. Sets the vote of all colluding members
to vote-collude
  ; Recording individual votes for bookkeeping
  ask link-neighbors [vote-truthful]

  set individual-votes n-values array:length social-policy-vector [0]
  foreach [votes] of link-neighbors [
    v -> set individual-votes (map
      [[i-v x] -> i-v + x]
      individual-votes v)
  ]

  ; Assign votes
  ask link-neighbors [
    ifelse random-float 1 < proportion-cooperate
    [
      set votes [normalized-utility] of myself
      ask my-links [set color yellow]
    ]
    [
      ask my-links [set color red]
    ]
  ]
  ; Recording colluding votes for bookkeeping
  set votes map [x -> x * count link-neighbors] total-utility
  ; Advantage is the votes the colluding party gains from colluding, as opposed to voting individually
  set advantage (map [[v i-v] -> v - i-v] votes individual-votes)
end

; For the two issues that are shown on the grid, color the quadrant green if the outcome corresponding with it has the same sign.
to show-winners
  ask patches with [pxcor != 0  and  pycor != 0]  [set pcolor black]

  ; Find whether or not the sum of votes on x and y axises were positive or negative
  let x-sign (array:item social-policy-vector x-axis) / abs (array:item social-policy-vector  x-axis)
  let y-sign (array:item social-policy-vector y-axis) / abs (array:item social-policy-vector y-axis )

  ; Set the appropriate quadrant green
  ask patches with [pxcor * x-sign >= 1 and pycor * y-sign >= 1]
  [set pcolor green - 3]
end

; Sets votes to be a multiple of utilities
to vote-truthful
  let j sqrt (1 / sum map [u -> u ^ 2] utilities)
  set votes map[u -> u * j] utilities
end

to move-to-result
  let next-xcor array:item social-policy-vector x-axis
  let next-ycor array:item social-policy-vector y-axis
  set xcor ifelse-value abs next-xcor > max-pxcor [(max-pxcor - 1) * next-xcor / abs next-xcor] [next-xcor]
  set ycor ifelse-value abs next-ycor > max-pycor [(max-pycor - 1) * next-ycor / abs next-ycor] [next-ycor]
end

; Computes dot product of two vectors
to-report dot-product [a-vector b-vector]
  report sum (map [[a b] -> a * b] a-vector b-vector)
end

; Given a vector, Computes a vector with a magnitude of 1
to-report normalize [vector]
  let sqrt-squared-sum sqrt sum map [u -> u ^ 2] vector
  report map [u -> u / sqrt-squared-sum ] vector
end

; Given a matrix row, compute a vect
to-report matrix-normalize [matrix-row]
  let sqrt-squared-sum sqrt sum map [u -> u ^ 2] item 0 matrix:to-row-list matrix-row
  report matrix:times matrix-row sqrt-squared-sum
end

; Utility gain reporter for monitor
to-report total-utility-gain
  let index 0

  ; array is used to avoid creating new arrays every time the utilities of voters are summed
  let sum-utilities array:from-list n-values array:length social-policy-vector [0]
  foreach issues [i -> array:set sum-utilities i sum [item i utilities] of voters]

  let utility-gain (map [[spv s-u]-> (ifelse-value
    spv = 0
    [0]
    spv > 0
    [s-u]
    spv < 0
    [-1 * s-u])
  ] array:to-list social-policy-vector array:to-list sum-utilities )

  report utility-gain
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

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; These are entirely for behavior space experiments

;to store-outcome
;  set results fput social-policy-vector results
;end
;
;to-report has-converged?
;  if ticks < 4 [report false]
;  let current-outcome item 0 results
;  let index 1
;  while [index <= 3]
;  [
;    if member? false (map [[c-o r] -> abs (c-o - r) < .1] current-outcome (item index results)) [
;    report false
;  ]
;    set index index + 1
;  ]
;  report true
;end

; Reports Shapley value vector for a colluding group.
; See Notion for more details
to-report shapley-value
  ; Since no colluding has been done when there is only one colluding member, report 0
  if count link-neighbors <= 1 [report 0]

  let p n-values length social-policy-vector [0]
  ask link-neighbors [set p (map [[u x] -> u + x] utilities p)]
  report (map [[a t-a x] -> a / t-a * x] advantage total-advantage p )
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
500.0
100
1
voters
HORIZONTAL

SLIDER
0
50
219
83
number-of-issues
number-of-issues
2
10
2.0
1
1
Issues
HORIZONTAL

BUTTON
0
164
102
216
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
217
218
251
Vote!
go
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
164
219
216
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

SWITCH
0
252
103
285
QV?
QV?
0
1
-1000

BUTTON
105
252
218
286
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

MONITOR
715
179
1008
224
Social Policy Vector
map [x -> precision x 2]array:to-list social-policy-vector
2
1
11

MONITOR
715
131
813
176
Maximal Utility?
maximal-utility?
17
1
11

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
84
243
129
utility-distribution
utility-distribution
"Normal mean = 0" "Normal mean != 0" "Bimodal one direction" "Bimodal all directions" "Indifferent Majority vs. Passionate Minority"
0

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
130
218
163
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
715
225
1008
270
Utility Gain
map [x -> precision x 2] total-utility-gain
2
1
11

SLIDER
0
321
248
354
collusion-growth
collusion-growth
0
100
100.0
1
1
links per tick
HORIZONTAL

SLIDER
0
356
248
389
proportion-cooperate
proportion-cooperate
0
1
1.0
.05
1
NIL
HORIZONTAL

MONITOR
716
272
873
317
Advantage From Collusion
0
17
1
11

SLIDER
0
286
249
319
colluding-turtles-created
colluding-turtles-created
0
10
10.0
1
1
Colluding Turtles
HORIZONTAL

@#$#@#$#@
## WHAT IS IT?

This a model of Quadratic Voting, otherwise known as QV. QV has the following properties:

  * Each Voting Agent is allocated an equal amount of "Voice Credits", which may be used to purchase votes. 
  * During each election, there exists a number of referenda can to vote on. Each referendum can be either be voted for, or against. 
  * A Voting Agent may buy x votes for or against an referendum, by spending x<sup>2</sup> voice credits.

For example, if each agent has 100 voice credits, it may be inclined to spend all 100 voice credits on 10 vote for a single referendum, if it only cares about that specific referendum. If an agent wishes to split his 100 voice credits on 4 different referenda, he can spend 25 voice credits on each, gaining 5 votes for each referenda.  

## HOW IT WORKS 

How an agent votes is affected by their utility value for each issue. The Utility value is how much the agent will gain if the issue passes. (If it is negative, the agent will lose if the issue passes.) This may be represented in real life by how much the issue affects them, for example, a gay couple will have a higher utility value on the issue of gay marriage, as opposed to a straight couple, who are simply supporters of gay marriage, but it does not directly affect them.

Agents can be grouped into the following three categories:

  * Truthful Voters (Marked by Purple Agents)
  * Strategic Voters (Marked by Pink Agents)
  * Colluding Voters (Marked by a yellow link to a Turtle-Shaped Agent)

Each of the categories of voters follow different rules when voting.

Truthful voters will map their utilites of each issue to votes, so their votes are proportional to their utilities. 

Strategic Voters will act like Truthful voters, unless a poll has been taken. If a poll has been taken, they will multiply each of their Truthful Votes by a calculated "marginal pivotality", which is an estimate on how likely the agent is to flip the outcome in their favor.  The marginal pivotality is calculated from the poll results. If the calculated marginal pivotality is extremely close to zero, a strategic voter will vote like the truthful voter.

Collduing Voters will split their votes equally among several different issues, according to the colluding group that they are apart of.  

Colluding groups will form when an agent loses in at least two referenda, and the colluding group will split their votes among the referenda the initial voter lost in. Colluding groups will always be looking for more voters to join, and if they find a voter that has agreeing utilities, and the colluding groups' utilities match the voter's utilities more than it's current group, it will recruit the voter. 

## HOW TO USE IT

Before pressing setup(hotkey: s), set the number of voters, proportion of strategic voters, and the number of issues to vote on. 

After pressing setup, a number of voting agents will spawn.  Their utility will be represented by their position on the view. You can change which issue will be on the view, by changing the sliders "x-axis and y-axis", then pressing refresh(hotkey: r).

Press vote(hotkey: v) to have the agents vote.  The quadrant which won the vote will turn green, and a green star will appear to show the results of the vote.  The closer the star is to the white axis, the closer the vote was!

Some additional options are noted in "Things to try"

## THINGS TO NOTICE

///Don't really know what to put here that won't be on Things to Try

## THINGS TO TRY

Besides QV, this model also has other supplementary features, Polling and Collusion.

Under normal circumstances, the agents will vote according to their utilities. However, when a poll of the population is taken "strategic" voters will use the information from the last poll to inform their choices.  

Collusion is when agents with similar and non-conflicting interests will split their votes to have a greater voice. For example, agents 1 and 2 want issues 1 and 2 to be passed respectively, and do not care about any other issue passing.  Individually, each agent will spend all their voice credits toward each issue they care about. However, each voter instead can collude, and split their votes between the two issues, increase their collective say both issues. 

Try changing the utility distribution.  Notice that the in the Minority v. Majority distribution the minority will likely win if there are more issues.  Can you guess why? In the Normal mean != 0 distribution there isn't much a difference between the strategic voters and the truthful voters.  Why is that?

Flipping the QV? switch will toggle the model between QV and one person one vote (1p1v).  Observe the differences between 1p1v and QV, especially in the Minority vs. Majority scenario. 

Turn up the proportion of strategic voters to 1, increase the percentage of the population polled, and press "Poll and Vote" repeatedly. Sometimes the results will oscillate between several different outcomes.  The Yellow star represents the result of the poll. 

Try changing the number of Colluding Turtles created per vote.  When you increase the number of Colluding turtles created per second, notice how quickly the outcome flips when the utility distribution is Normal mean = 0 or Bimodal one direction, and how it can easily flip back in the other direction. 


## EXTENDING THE MODEL

QV may be suspectable to misinformation of ones own utilities, since votes spent on one issue will mean they aren't spent on another.  Can you implement an agent that can influence voters?

## NETLOGO FEATURES

This model extensively uses the "map" command with multiple array inputs, since the position in a list of utilities or results matters. A challenge when making this model was the readbility as a result of this.

## RELATED MODELS

TODO: Finding voting models

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
