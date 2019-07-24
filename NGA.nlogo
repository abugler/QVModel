breed[voters voter]
breed[influencers influencer]
voters-own[
  x-utility
  y-utility
  x-vote
  y-vote
  last-x-vote
  last-y-vote
  strategic?
]
influencers-own[
  influence-type
  radius
]
globals
[
  change-of-x
  change-of-y
  last-step-size
  social-policy-vector
  last-three-runs-acceptable
]

to setup
  clear-all
  reset-ticks
  ; Create Unit Circle, containing varied opinions
  ask patches with [pxcor = 0 or pycor = 0 ] [set pcolor white]
  ask patches with [ abs (pxcor ^ 2 + pycor ^ 2 - max-pxcor ^ 2) < max-pxcor] [set pcolor red]

  ; Sprout Voters
  ; The xcor and ycor of the voters represent the utility gain, if the social policy xcor has the equivalent sign.
  ask n-of number-of-voters patches with [ pxcor ^ 2 + pycor ^ 2 - max-pxcor ^ 2 < 0] [
    sprout-voters 1 [
      set strategic? (random-float 1 < proportion-of-strategic-voters)
      ifelse strategic?
      [set color pink]
      [set color violet]
      set x-utility xcor
      set y-utility ycor
    ]
  ]

  ; This turtle represents the social policy
  ask one-of patches with [pxcor = 0 and pycor = 0][
    sprout 1 [
      set color green
      set shape "triangle"
      set size 3
    ]
  ]
  set social-policy-vector one-of turtles with [color = green and shape = "triangle"]
  set last-three-runs-acceptable (list)
end

to vote-NGA
  ; Have influencers change the opinion of the voters, to more align with them
  ask influencers [influence]
  return-to-true-utility

  ; Have voters calculate their preferred change in the SP vector, and take the averages of all the change
  ask voters [calculate-preferred-change-NGA]
  let ave-votes-x mean [x-vote] of voters
  let ave-votes-y mean [y-vote] of voters

  ; Increment by step size
  ask social-policy-vector
  [
    set xcor xcor + ave-votes-x * step-size
    set ycor ycor + ave-votes-y * step-size
  ]
  ; Save last change
  set change-of-x ave-votes-x * step-size
  set change-of-y ave-votes-y * step-size
  set last-step-size step-size

  ; Bookkeeping for BS experiment
  set last-three-runs-acceptable fput acceptable? last-three-runs-acceptable
  if ticks > 2 [set last-three-runs-acceptable remove-item 3 last-three-runs-acceptable]

  tick
end

to vote-1p1v
  ; Have influencers change the opinion of the voters, to more align with them
  ask influencers [influence]

  ; Ask voters to vote in the direction of the sign of their utility
  let total-x-votes 0
  let total-y-votes 0
  ask voters [
    set total-x-votes total-x-votes + ifelse-value xcor != 0  [xcor / abs xcor] [0]  ;; JACOB: You are getting the sign of a number a few times in this function. I'd make a sign function that takes a number and outputs +1 or -1
    set total-y-votes total-y-votes + ifelse-value ycor != 0  [ycor / abs ycor] [0]
  ]
  ; Change social policy vector to reflect this
  ask social-policy-vector
  [
    set xcor (ifelse-value total-y-votes = 0 [0] abs total-x-votes > max-pxcor [max-pxcor * total-x-votes / abs total-x-votes] [total-x-votes]) ;; JACOB: I think a three way conditional is too much for one line.
    set ycor (ifelse-value total-x-votes = 0 [0] abs total-y-votes > max-pycor [max-pycor * total-y-votes / abs total-y-votes] [total-y-votes])
  ]
  tick
end

to calculate-preferred-change-NGA
  ; Save last vote
  set last-x-vote x-vote
  set last-y-vote y-vote

  ; Add the voters preferred change to the overall change
  set x-vote preferred-x-change
  set y-vote preferred-y-change

  ; If the length of the preference vector is greater than the radius of the unit circle
  ; shorten it's length to the unit circle radius
  if (x-vote ^ 2 + y-vote ^ 2 > max-pxcor ^ 2)
  [
    set x-vote x-vote / sqrt (x-vote ^ 2 + y-vote ^ 2) * max-pxcor  ;; JACOB: You calculate the distnace of a point from the origin a few times. I would write a procedure for that. Use it on the if statement one line above also.
    set y-vote y-vote / sqrt (x-vote ^ 2 + y-vote ^ 2) * max-pxcor
  ]
end

;; Calculated the preferred change of x, strategically and truthfully
to-report preferred-x-change
  ifelse strategic? and ticks != 0
  [report xcor - ([xcor] of social-policy-vector + change-of-x - last-x-vote * last-step-size / count voters )]
  [report xcor - [xcor] of social-policy-vector]
end

;; Calculated the preferred change of y, strategically and truthfully
to-report preferred-y-change
  ifelse strategic? and ticks != 0
  [report ycor - ([ycor] of social-policy-vector + change-of-y - last-y-vote * last-step-size / count voters)]
  [report ycor - [ycor] of social-policy-vector]
end

; influencer method, changes the perceived utility of voters in its radius
to influence
  ; Find new voters in its radius to influence, and stop influencing voters that are no longer is it's radius
  create-links-to voters with [distance myself < [radius] of myself]
  ask links [set color yellow]
  ask links with [link-length > [radius] of myself][die]
  ask link-neighbors [
    (ifelse
      ; Attractors will influence voters to perceive their utilities more similar to itself.
      ; For example, this could be a 'fake news' distributor, which convinces ideologically similar people to take his stance on this issue
      [influence-type] of myself = "Attractor" ;
      [
        face myself
        forward distance myself * influencer-strength
      ]
      ; Taboo will influence voters to perceive their utilities to be different from itself.
      ; For example, it is Taboo in some parts of America to deny climate change, even if climate change policies may damage your livelihood
      [influence-type] of myself = "Taboo"
      [
        face myself
        rt 180
        if [radius] of myself - distance myself > 0  ;; JACOB: I think this would be clearer: if distance myself < [radius] myself.
        [forward ([radius] of myself - distance myself) * influencer-strength + .5]
      ]
      [influence-type] of myself = "Extremist"
      ; Extremist will influence voters to exaggrate their perceived utilities.
      ; This kind of Extremist pressure will occur in divided political climates
      [
        face patch 0 0
        rt 180
        forward influencer-strength * (sqrt(max-pxcor ^ 2 + max-pycor ^ 2) - distance patch 0 0)
      ]
      [influence-type] of myself = "Centrist"
      ; Centrist will influence voters to under-represent their perceived utilities
      ; Centrism will occur during times of economic growth, where the status quo is generally considered good
      [
        face patch 0 0
        forward influencer-strength * distance patch 0 0
      ]
    )
  ]
end

to return-to-true-utility
  ask voters with [count link-neighbors = 0][
    let true-utility patch x-utility y-utility
    face true-utility
    forward .5 * distance true-utility
    (ifelse (abs(x-utility - xcor)  > .01 and abs(y-utility - ycor)  > .01)
    [set color red]
      strategic?
      [set color pink]
      [set color violet]
    )
  ]
end

to insert-influencers
    make-influencer mouse-xcor mouse-ycor
end

to make-influencer [x y]
  ask patch x y [
  sprout-influencers 1 [
    set shape "monster"
    set size influencer-radius / 5
    set radius influencer-radius
    ; Find voters nearby to connect with
    create-links-to voters with
    [distance myself < influencer-radius]
    [
      set color yellow
    ]
    ; Show their real utility with a stamp, and turn them red
    ask link-neighbors [
      if (xcor = x-utility and ycor = y-utility)[
        set color blue
        stamp
      ]
      set color red
      face myself
    ]
      set influence-type Influencer-type
      (ifelse
        influence-type = "Attractor" [set color cyan]
        influence-type = "Taboo" [set color orange]
        influence-type = "Extremist" [set color magenta]
        influence-type = "Centrist" [set color grey]
      )
  ]
  ]
end

to-report total-utility-gain
  let total-utility-x 0
  let total-utility-y 0
  if ticks != 0[
    ; social policy vector
    let sp-vector-x  [xcor] of social-policy-vector
    let sp-vector-y  [ycor] of social-policy-vector
    if sp-vector-x != 0[
      ask voters[
        set total-utility-x total-utility-x + x-utility * sp-vector-x / abs sp-vector-x
      ]
    ]
    if sp-vector-y != 0[
      ask voters[
        set total-utility-y total-utility-y + y-utility * sp-vector-y / abs sp-vector-y
      ]
    ]
  ]
  report list total-utility-x total-utility-y
end

to delete-voters
  if mouse-down? [
    ask patch mouse-xcor mouse-ycor [
      ask voters in-radius 2 [die]
    ]
  ]
end

;;;;;;;; These two methods are for monitoring behavior space experiments!
;;;;;;;; Specificially, they are looking for the optimal step size for an acceptable outcome.
;;;;;;;; To be considered acceptable, the SP vector must be within 95% of the distance from the origin
to-report acceptable?
  let SPV social-policy-vector
  let desired-SPV-x mean [x-utility] of voters
  let desired-SPV-y mean [y-utility] of voters
  report (desired-SPV-x - [xcor] of SPV) ^ 2 + (desired-SPV-y - [ycor] of SPV) ^ 2 < .05 * sqrt ([xcor] of SPV ^ 2 + [ycor] of SPV ^ 2)
end

to-report last-three-acceptable?
  report (not member? false last-three-runs-acceptable) and (length last-three-runs-acceptable = 3)
end
@#$#@#$#@
GRAPHICS-WINDOW
210
10
623
424
-1
-1
5.0
1
10
1
1
1
0
0
0
1
-40
40
-40
40
0
0
1
ticks
30.0

BUTTON
0
116
95
149
Vote
ifelse NGA? [vote-NGA][vote-1p1v]
NIL
1
T
OBSERVER
NIL
D
NIL
NIL
1

BUTTON
53
81
138
114
Setup
setup
NIL
1
T
OBSERVER
NIL
S
NIL
NIL
1

SLIDER
0
11
203
44
number-of-voters
number-of-voters
1
1000
1000.0
1
1
NIL
HORIZONTAL

SLIDER
0
187
201
220
step-size
step-size
0
1
1.0
.05
1
NIL
HORIZONTAL

MONITOR
0
223
90
268
Utility
total-utility-gain
3
1
11

BUTTON
630
11
817
44
Insert Influencer
insert-influencers
NIL
1
T
OBSERVER
NIL
A
NIL
NIL
1

SLIDER
633
117
819
150
influencer-radius
influencer-radius
0
40
40.0
1
1
NIL
HORIZONTAL

MONITOR
89
223
202
268
Current Policy Vector
map [x -> precision x 2 ] (one-of [list xcor ycor] of turtles with [color = green and shape = \"triangle\"])
2
1
11

BUTTON
631
46
818
79
Toggle Influencer Links
ask links [ set hidden? not hidden?]
NIL
1
T
OBSERVER
NIL
Q
NIL
NIL
1

BUTTON
632
81
818
114
Delete All Influencers
ask influencers [die]
NIL
1
T
OBSERVER
NIL
W
NIL
NIL
1

SLIDER
0
45
203
78
proportion-of-strategic-voters
proportion-of-strategic-voters
0
1
1.0
.01
1
NIL
HORIZONTAL

BUTTON
98
116
202
149
Vote Forever
ifelse NGA? [vote-NGA][vote-1p1v]
T
1
T
OBSERVER
NIL
F
NIL
NIL
1

SWITCH
0
151
95
184
NGA?
NGA?
0
1
-1000

BUTTON
98
151
200
184
Toggle NGA?
set NGA? not NGA?
NIL
1
T
OBSERVER
NIL
R
NIL
NIL
1

SLIDER
633
153
819
186
influencer-strength
influencer-strength
0
1
0.49
.01
1
NIL
HORIZONTAL

CHOOSER
842
25
980
70
Influencer-Type
Influencer-Type
"Attractor" "Taboo" "Extremist" "Centrist"
3

BUTTON
637
211
751
244
NIL
delete-voters
T
1
T
OBSERVER
NIL
E
NIL
NIL
1

MONITOR
39
299
119
344
Acceptable?
Acceptable?
17
1
11

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

monster
false
0
Polygon -7500403 true true 75 150 90 195 210 195 225 150 255 120 255 45 180 0 120 0 45 45 45 120
Circle -16777216 true false 165 60 60
Circle -16777216 true false 75 60 60
Polygon -7500403 true true 225 150 285 195 285 285 255 300 255 210 180 165
Polygon -7500403 true true 75 150 15 195 15 285 45 300 45 210 120 165
Polygon -7500403 true true 210 210 225 285 195 285 165 165
Polygon -7500403 true true 90 210 75 285 105 285 135 165
Rectangle -7500403 true true 135 165 165 270

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
  <experiment name="NGA-optimal-step" repetitions="1000" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>ifelse NGA? [vote-NGA][vote-1p1v]</go>
    <timeLimit steps="100"/>
    <exitCondition>last-three-acceptable?</exitCondition>
    <metric>total-utility-gain</metric>
    <metric>[list xcor ycor] of social-policy-vector</metric>
    <metric>ticks</metric>
    <enumeratedValueSet variable="number-of-voters">
      <value value="1000"/>
    </enumeratedValueSet>
    <steppedValueSet variable="step-size" first="0.05" step="0.05" last="0.95"/>
    <steppedValueSet variable="proportion-of-strategic-voters" first="0.25" step="0.05" last="0.75"/>
    <enumeratedValueSet variable="NGA?">
      <value value="true"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="NGA-strategic" repetitions="1000" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>vote-NGA</go>
    <timeLimit steps="10"/>
    <metric>total-utility-gain</metric>
    <metric>map [x -&gt; precision x 2 ] [list xcor ycor] of social-policy-vector</metric>
    <steppedValueSet variable="step-size" first="0.05" step="0.05" last="1"/>
    <enumeratedValueSet variable="number-of-voters">
      <value value="50"/>
      <value value="100"/>
      <value value="250"/>
      <value value="500"/>
      <value value="1000"/>
    </enumeratedValueSet>
    <steppedValueSet variable="proportion-of-strategic-voters" first="0.05" step="0.05" last="1"/>
  </experiment>
  <experiment name="NGA-influenced" repetitions="10000" runMetricsEveryStep="false">
    <setup>setup
make-influencer ((random max-pxcor) - 2 * max-pxcor) ((random max-pycor) - 2 * max-pycor)</setup>
    <go>ifelse NGA?[vote-NGA][vote-1p1v]</go>
    <timeLimit steps="1"/>
    <metric>total-utility-gain</metric>
    <metric>map [x -&gt; precision x 2 ] [list xcor ycor] of οne-of turtles with [shape = "triangle"]</metric>
    <steppedValueSet variable="influencer-radius" first="5" step="5" last="25"/>
    <enumeratedValueSet variable="number-of-voters">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="step-size">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="proportion-of-strategic-voters">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Influencer-Type">
      <value value="&quot;Attractor&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="NGA?">
      <value value="true"/>
      <value value="false"/>
    </enumeratedValueSet>
    <steppedValueSet variable="influencer-strength" first="0.05" step="0.05" last="1"/>
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
