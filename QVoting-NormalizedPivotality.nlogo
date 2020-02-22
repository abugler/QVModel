extensions [py]
__includes ["utils.nls"]
breed [voters voter]
breed [referenda referendum]
voters-own [
  utility
  voice-credits
  last-voice-credits-spent
  votes-cast
  perceived-pivotality
]
referenda-own [
  votes-list
  sum-of-votes
  outcome
]

globals[
  the-referendum
  a-value
  b-value
  payoff-list
  payoff-sign-list
  vote-sum-list
  mean-median-same-sign-list
]


;***************SETUP PROCEDURES*******************
to setup
  clear-all
  reset-ticks

  set payoff-list (list)
  set payoff-sign-list (list)
  set vote-sum-list (list)
  set mean-median-same-sign-list (list)

  spawn-voters-with-utilities
  spawn-referenda
  set the-referendum one-of referenda
  draw-axes-mean-and-median-utilities
  py:setup py:python
  py:run "import scipy.stats as stats"
end

to reset
  clear-turtles
  clear-drawing

  spawn-voters-with-utilities
  spawn-referenda
  set the-referendum one-of referenda
  draw-axes-mean-and-median-utilities
  clear-all-plots
  setup-plots
  update-plots
end

;; spawns voters with random utilities for each issue
to spawn-voters-with-utilities

  (ifelse
    calibration = "manual" [create-voters-with-manually-chosen-utililties]
    calibration = "1. prop8-mean>0" or calibration = "2. prop8-mean=0" [create-voters-with-prop8-utility-dist]
  )

  ask voters [
    set color grey
    set shape "face neutral"
    set-xcor-to-utility
  ]
end


to create-voters-with-prop8-utility-dist
  ; This calibration is based off of sections 2.1 and 2.4 in Chandar and Weyl 2019
  ; utility units here are in units of $10k

  let het-support 0
  ifelse calibration = "1. prop8-mean>0" [
    set het-support 0.48 ;support of the heterosexual population for a calibration with mean utility > 0
  ] [
    set het-support 0.36 ;support of the heterosexual population for a calibration with mean utility = 0
  ]

  create-voters number-of-voters [
    let random-num random-float 1
    (ifelse
      random-num < 0.007 [ ; This is the portion of the population that is LGBT and in a relationship
        set utility 2 + random-float 18
      ]
      random-num < 0.04 [ ; This the portion of the population that is LGBT and in a relationship
        set utility 0.5 + random-float 3.5
      ]
      random-num < het-support [ ; This is the % of the non-LGBT population that supported gay marriage
        set utility random-float 1
      ]
      [ ; the remaining % of the population opposed gay marriage
        set utility random-float -1
      ]
    )
  ]
end


to create-voters-with-manually-chosen-utililties
  create-voters round (number-of-voters * (1 - minority-fraction)) [
    set utility random-normal majority-mean-utility majority-utility-stdev ; If the utility > 0, voter wants the referendum to pass and vice versa. The larger abs utility is, the more the voter cares.
  ]
  create-voters round (number-of-voters * minority-fraction) [
    set utility random-normal minority-mean-utility minority-utility-stdev ; If the utility > 0, voter wants the referendum to pass and vice versa. The larger abs utility is, the more the voter cares.
  ]
end


to set-xcor-to-utility
  ifelse abs utility < max-pxcor [ ;; if the turtle can set its utility to the xcor, then do it
    set xcor utility
  ] [  ; if utility's magnitude is too large to be represented by the xcor, just hide it.
    hide-turtle
  ]
end

to spawn-referenda
  ask patches with [pycor = max-pycor and pxcor = 0][
    sprout-referenda 1 [
      set shape "square"
      set color white
      set votes-list (list)
      set size 2
  ]]
end

to draw-axes-mean-and-median-utilities
  draw-line 0 (min-pycor - 0.5) 0 white false ""  0 ; y-axis
  draw-line (min-pxcor - 0.5) 0 90 white false ""  0; x-axis

  draw-line (mean [utility] of voters) (min-pycor - 0.5) 0 green true "mean utility"  2
  draw-line (median [utility] of voters) (min-pycor - 0.5) 0 yellow true "median utility"  3

end

to draw-line [x-cor y-cor direction lcolor dotted? l-label backtrack]
  crt 1 [
    set size 0
    set label l-label
    set color lcolor
    set label-color color
    set xcor x-cor
    set ycor y-cor
    set heading direction
    pen-down
    ifelse dotted? [
      let dots 20
      let dot-length world-width / (dots * 2)
      repeat dots [
        pen-down
        fd dot-length
        pen-up
        fd dot-length
      ]

    ] [
      fd world-width
      fd .99
    ]
    pen-up
    back backtrack
  ]
end
;***************GO PROCEDURES*******************
to go
  (ifelse
    voting-mechanism = "QV" [vote-QV the-referendum]
    voting-mechanism = "1p1v" [vote-1p1v the-referendum])

  ask voters [visualize-votes]
  ask the-referendum [visualize-outcome]

  set payoff-list lput payoff payoff-list
  set payoff-sign-list lput ifelse-value payoff > 0 [1] [0] payoff-sign-list
  set vote-sum-list lput vote-sum vote-sum-list
  set mean-median-same-sign-list lput mean-median-same-sign? mean-median-same-sign-list
  tick
end


to vote-1p1v [active-referendum] ;; Procedure for voters to vote using 1p1v mechanism
  let list-of-votes (list)

  ask voters [
    set votes-cast sign-of utility
    set list-of-votes fput votes-cast list-of-votes
  ]

  ask active-referendum [
    set votes-list list-of-votes
    set sum-of-votes sum list-of-votes

    ifelse sum-of-votes > 0 [
      set outcome 1
      set color green
    ] [
      set outcome -1
      set color red
    ]
  ]

end

to vote-QV [active-referendum]
  let list-of-votes (list)

  assign-p-values-to-voters

  ask voters [
    set votes-cast (sign-of utility) * sqrt voice-credits-spent active-referendum
    set list-of-votes fput votes-cast list-of-votes
  ]

  ask active-referendum [
    set votes-list list-of-votes
    set sum-of-votes sum list-of-votes
    ifelse sum-of-votes > 0 [
      set outcome 1
      set color green
    ] [
      set outcome -1
      set color red
    ]
  ]
end



to assign-p-values-to-voters
  ifelse marginal-pivotality = 1 or variance-of-perceived-pivotality = 0[
    ask voters [set perceived-pivotality marginal-pivotality]
  ]
  [
    ; using a beta dist for p-value
    ; used equations here https://stats.stackexchange.com/questions/12232/calculating-the-parameters-of-a-beta-distribution-using-the-mean-and-variance
    let var variance-of-perceived-pivotality
    let ave marginal-pivotality
    let max-var marginal-pivotality - marginal-pivotality ^ 2
    if var > max-var [set var .99 * max-var]
    set a-value ave ^ 2 * ( (1 - ave) / var - 1 / ave)
    set b-value a-value * (1 / ave - 1)

    py:set "a" a-value
    py:set "b" b-value
    py:set "number_of_voters" number-of-voters
    let list-of-p py:runresult "stats.beta.rvs(a, b, size = number_of_voters)"

    ask voters [set perceived-pivotality item who list-of-p]
  ]
end


to-report voice-credits-spent [active-referendum] ; voter function
  let spent-voice-credits ifelse-value limit-votes? [
    min list ( (utility * perceived-pivotality) ^ 2) voice-credits
  ] [
    (utility * perceived-pivotality) ^ 2
  ]
  set last-voice-credits-spent spent-voice-credits
  report spent-voice-credits
end


to-report payoff ;;should be zero when setup

  let last-outcome [outcome] of the-referendum
  if last-outcome = 0 [report 0]

  let payoff-sum 0
  ask voters [
    set payoff-sum payoff-sum + utility * (sign-of last-outcome)
  ]

  if payoff-include-votes-cost? [
    ask voters [
      set payoff-sum payoff-sum - last-voice-credits-spent + mean [last-voice-credits-spent] of other voters
    ]
  ]

  report payoff-sum
end

to-report utilities-mean
  report mean [utility] of voters
end

to-report utilities-median
  report median [utility] of voters
end

to-report vote-sum
  report [sum-of-votes] of the-referendum
end

to-report mean-median-same-sign?
  report ifelse-value (sign-of utilities-mean = sign-of utilities-median) [1] [0]
end

to visualize-votes
  ifelse abs votes-cast <= max-pycor [ ; if votes cast can be represnted by ycor (fits on the screen) then display it
    set ycor votes-cast
  ] [ ; if votes cast is too large to be displayed as ycor, then hide the turtle
    hide-turtle
  ]

  ifelse [outcome] of the-referendum = sign-of utility [
    set color green
    set shape "face happy"
  ] [
    set color red
    set shape "face sad"
  ]
end

to visualize-outcome
  ifelse outcome = 1 [
    set color green
    set xcor 1
  ] [
    set color red
    set xcor -1
  ]

end
@#$#@#$#@
GRAPHICS-WINDOW
311
10
772
472
-1
-1
8.9
1
10
1
1
1
0
0
0
1
-25
25
-25
25
1
1
1
ticks
30.0

SLIDER
2
100
174
133
number-of-voters
number-of-voters
1
10001
1471.0
10
1
NIL
HORIZONTAL

BUTTON
0
62
55
95
vote
go
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
11
63
44
setup
setup\nreset-ticks
NIL
1
T
OBSERVER
NIL
S
NIL
NIL
1

SWITCH
212
471
320
504
limit-votes?
limit-votes?
1
1
-1000

PLOT
772
22
1027
214
Number of Voters by Votes cast
Number of Votes
Number of Voters
-12.0
12.0
0.0
10.0
true
false
"" ""
PENS
"positive" 1.0 1 -13840069 true "" "histogram filter [a -> a >= 0] [votes-list] of the-referendum"
"negative" 1.0 1 -2674135 true "" "histogram filter [a -> a < 0] [votes-list] of the-referendum"
"pen-2" 1.0 0 -16777216 true "" "plot-y-axis"

MONITOR
6
370
100
415
payoff
payoff
2
1
11

MONITOR
105
370
192
415
vote-sum
vote-sum
2
1
11

PLOT
772
218
1024
411
Distrubution of Utilities
Utility gain if passed
Number of Voters
-12.0
12.0
0.0
10.0
true
false
"" "if ticks != 0 [set-plot-x-range (round (min [utility] of voters) - 1) (round (max [utility] of voters + 1))]\n"
PENS
"default" 1.0 1 -13840069 true "" "histogram [utility] of voters with [utility >= 0]"
"pen-1" 1.0 1 -2674135 true "" "histogram [utility] of voters with [utility < 0]"
"pen-2" 1.0 0 -16777216 true "" "plot-y-axis"

MONITOR
118
419
222
464
mean utilities
utilities-mean
3
1
11

SLIDER
0
228
160
261
majority-mean-utility
majority-mean-utility
-10
10
-0.5
.5
1
NIL
HORIZONTAL

SLIDER
160
227
306
260
majority-utility-stdev
majority-utility-stdev
0
10
1.5
0.5
1
NIL
HORIZONTAL

SLIDER
5
336
231
369
variance-of-perceived-pivotality
variance-of-perceived-pivotality
0
0.083
0.083
.001
1
NIL
HORIZONTAL

SLIDER
4
300
190
333
marginal-pivotality
marginal-pivotality
.05
1
0.5
.05
1
NIL
HORIZONTAL

PLOT
1035
21
1282
214
Distribution of perceived Marginal Pivotality
Perceived Marginal Pivotality
Number of Voters
0.0
1.0
0.0
10.0
true
false
"" "set-plot-y-range 0 10"
PENS
"pen-1" 0.1 1 -13345367 true "" "histogram [perceived-pivotality] of voters"

SWITCH
5
471
209
504
payoff-include-votes-cost?
payoff-include-votes-cost?
1
1
-1000

CHOOSER
164
52
295
97
voting-mechanism
voting-mechanism
"1p1v" "QV"
1

SLIDER
2
134
174
167
minority-fraction
minority-fraction
0
.5
0.06
.01
1
NIL
HORIZONTAL

SLIDER
0
262
159
295
minority-mean-utility
minority-mean-utility
-10
10
10.0
1
1
NIL
HORIZONTAL

SLIDER
161
262
306
295
minority-utility-stdev
minority-utility-stdev
0
10
1.0
0.5
1
NIL
HORIZONTAL

BUTTON
82
12
145
45
NIL
reset\n
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
0

BUTTON
61
62
160
95
reset & vote
reset \ngo
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
0

MONITOR
4
419
114
464
median utilities 
utilities-median
2
1
11

CHOOSER
5
180
167
225
calibration
calibration
"manual" "1. prop8-mean>0" "2. prop8-mean=0"
1

TEXTBOX
177
181
319
223
manual calibration uses the utility sliders below. The others are preset.
11
0.0
1

@#$#@#$#@
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
  <experiment name="Is-Payoff-always-positive?" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="1"/>
    <metric>payoff</metric>
    <steppedValueSet variable="number-of-voters" first="5" step="5" last="1000"/>
    <steppedValueSet variable="marginal-pivotality" first="0.05" step="0.05" last="1"/>
    <enumeratedValueSet variable="voice-credits-given-per-tick">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="limit-votes?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-issues">
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Is payoff &gt; 0 for a varied p?" repetitions="1000" runMetricsEveryStep="false">
    <setup>;; The variance-of-perceived-pivotality in the behavior space is not the actual behavorspace
;; It is the proportion of the max-variance that will be used each run
set variance-of-perceived-pivotality variance-of-perceived-pivotality * (marginal-pivotality - marginal-pivotality ^ 2)
setup</setup>
    <go>go</go>
    <timeLimit steps="1"/>
    <metric>precision variance-of-perceived-pivotality 4</metric>
    <metric>sum-of-votes</metric>
    <metric>sum-of-utilities</metric>
    <metric>payoff &gt;= 0</metric>
    <steppedValueSet variable="marginal-pivotality" first="0.25" step="0.05" last="0.75"/>
    <steppedValueSet variable="variance-of-perceived-pivotality" first="0.25" step="0.1" last="0.85"/>
  </experiment>
  <experiment name="normalized-p" repetitions="1000" runMetricsEveryStep="false">
    <setup>if marginal-pivotality = .25 or marginal-pivotality = .75
[set variance-of-perceived-pivotality precision (variance-of-perceived-pivotality / 2) 4]

if marginal-pivotality = .15 or marginal-pivotality = .85
[set variance-of-perceived-pivotality precision (variance-of-perceived-pivotality / 5) 4]
setup</setup>
    <go>go</go>
    <timeLimit steps="1"/>
    <metric>variance-of-perceived-pivotality</metric>
    <metric>list-of-votes</metric>
    <metric>sum-of-votes</metric>
    <metric>sum-of-utilities</metric>
    <metric>payoff</metric>
    <enumeratedValueSet variable="number-of-voters">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="voice-credits-given-per-tick">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="mean-of-utilities">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="stdev-of-utilities">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="limit-votes?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="utility-cost-of-each-voice-credit">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="payoff-include-votes-cost?">
      <value value="false"/>
      <value value="true"/>
    </enumeratedValueSet>
    <steppedValueSet variable="variance-of-perceived-pivotality" first="0.005" step="0.005" last="0.08"/>
    <enumeratedValueSet variable="marginal-pivotality">
      <value value="0.15"/>
      <value value="0.25"/>
      <value value="0.5"/>
      <value value="0.75"/>
      <value value="0.85"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="1p1v-vs-QV (agg)" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>reset
go</go>
    <timeLimit steps="1000"/>
    <metric>mean payoff-sign-list</metric>
    <metric>mean payoff-list</metric>
    <metric>standard-deviation payoff-list</metric>
    <metric>mean vote-sum-list</metric>
    <metric>standard-deviation vote-sum-list</metric>
    <metric>mean mean-median-same-sign-list</metric>
    <enumeratedValueSet variable="number-of-voters">
      <value value="11"/>
      <value value="21"/>
      <value value="31"/>
      <value value="41"/>
      <value value="51"/>
      <value value="61"/>
      <value value="71"/>
      <value value="81"/>
      <value value="101"/>
      <value value="201"/>
      <value value="301"/>
      <value value="401"/>
      <value value="501"/>
      <value value="601"/>
      <value value="701"/>
      <value value="801"/>
      <value value="901"/>
      <value value="1001"/>
      <value value="5001"/>
      <value value="10001"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="minority-fraction">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="majority-mean-utility">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="majority-utility-stdev">
      <value value="1"/>
      <value value="3"/>
      <value value="6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="minority-mean-utility">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="minority-utility-stdev">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="marginal-pivotality">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="variance-of-perceived-pivotality">
      <value value="0"/>
      <value value="3.0E-4"/>
      <value value="0.001"/>
      <value value="0.01"/>
      <value value="0.02"/>
      <value value="0.03"/>
      <value value="0.04"/>
      <value value="0.05"/>
      <value value="0.06"/>
      <value value="0.07"/>
      <value value="0.08"/>
      <value value="0.083"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="limit-votes?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="payoff-include-votes-cost?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="voting-mechanism">
      <value value="&quot;1p1v&quot;"/>
      <value value="&quot;QV&quot;"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="1p1v-vs-QV-prop8" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>reset
go</go>
    <timeLimit steps="1000"/>
    <metric>mean payoff-sign-list</metric>
    <metric>mean payoff-list</metric>
    <metric>standard-deviation payoff-list</metric>
    <metric>mean vote-sum-list</metric>
    <metric>standard-deviation vote-sum-list</metric>
    <metric>mean mean-median-same-sign-list</metric>
    <enumeratedValueSet variable="number-of-voters">
      <value value="11"/>
      <value value="21"/>
      <value value="31"/>
      <value value="41"/>
      <value value="51"/>
      <value value="61"/>
      <value value="71"/>
      <value value="81"/>
      <value value="101"/>
      <value value="201"/>
      <value value="301"/>
      <value value="401"/>
      <value value="501"/>
      <value value="601"/>
      <value value="701"/>
      <value value="801"/>
      <value value="901"/>
      <value value="1001"/>
      <value value="5001"/>
      <value value="10001"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="minority-fraction">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="majority-mean-utility">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="majority-utility-stdev">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="minority-mean-utility">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="minority-utility-stdev">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="calibration">
      <value value="&quot;1. prop8-mean&gt;0&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="marginal-pivotality">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="variance-of-perceived-pivotality">
      <value value="0"/>
      <value value="3.0E-4"/>
      <value value="0.001"/>
      <value value="0.01"/>
      <value value="0.02"/>
      <value value="0.03"/>
      <value value="0.04"/>
      <value value="0.05"/>
      <value value="0.06"/>
      <value value="0.07"/>
      <value value="0.08"/>
      <value value="0.083"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="limit-votes?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="payoff-include-votes-cost?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="voting-mechanism">
      <value value="&quot;1p1v&quot;"/>
      <value value="&quot;QV&quot;"/>
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
