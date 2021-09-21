


;;;;;;;;;;;;;;;;;;;; BREEDS AND VARIABLES ;;;;;;;;;;;;;;;;;;;;

breed [farmers farmer]      ;; turtle-breed farmers


farmers-own [               ;; attributes of the farmers            
  farmer-state              ;; The current law-abiding level of the farmer [-1 1] --> [-1 - 0 > = fraudulent, [0 - 1 ] = complying
  risk-aversion             ;; for future implementation (now: random, static)
  risk-preference           ;; for future implementation (now: random, static)
  grade                     ;; The farmers 'reputation', this is changed based on the farmers state during inspection 
  times-caught              ;; Attribute to calculate the times the farmer is inspected and found fraudulent, set back after having to close his business
  total-times-caught        ;; Same as 'times-caught', but not set back after having to close his business, so this is cumulative
  closure-period-business   ;; Number of ticks the farmer has to close his business, if 0 the farmer will not have to close his business
  times-business-closure    ;; Number of times a farmer had to close his business
  farmer-state-memory       ;; Variable which stores the farmer-state of an unconsciosuly non-compliant-farmer, to re-establish when appropriate
  acceptation-level         ;; The probability of legislation compliance, same value with farmer's original farmer-state 
  social-influential-factor ;; The importance of social versus individual
  mean-neighbor-state       ;; The mean neighbors' state within social network
]


patches-own [               ;; attributes of the patches
  social-neighbors          ;; Surrounding patches within the scope-social-influence radius
  rumour                    ;; This attribute represents the rumour present at a patch when a farmer is found fraudulent. The value decays with time. 
] 


globals[                    ;; global variables, can be used anywhere in the model
  ; parameters -- set by switches:
; Social-pressure?          
; Inspection?                
; Education?
; Debug?
; Generate-random-seed?
  ; parameters -- set by sliders
; Number-of-=farmers
; Acceptation               ;; global population level of degree of Acceptation; each farmer's value derived from this
; Scope-social-influence    ;; if social influence, then this scope defines who each farmer's "social neighbours" are
; Social-factor             ;; global population level of degree of Social influence: each farmer's value derived from this
; Inspectors                ;; if Inspection, how many inspectors
; Risk-based-inspection     ;; to what degree are farmers to inspect picked at random, or based on previous behaviour?
; Detection-probability     ;; if a farmer is fraudulent, what is the probability that he will get caught?
; Closure-term-business     ;; if a farmer gets caught, how many time steps does his business have to close?
; Educators                 ;; if education, then how many educators are there?
; Education-probability     ;; if a farmer gets educated, what is the probability that he will accept this, i.e. become compliant?
; Unconsciously-non-compliant ;; percentage of farmers that unconsciously doesn't comply: .
  ; parameters -- set by inputs
  ; seed-used               ;; if no random seed is generated (switched off), then this input provides the fixed seed for the random generator. 

  number-of-educators       ;; taken from slider 
  number-of-inspectors      ;; taken from slider
  inspected-farmer          ;; used in procedure select-farmer-to-inspect: non-random when risk-based inspection.
  tempxcor                  ;; Variable to store x coordinate of inspected-farmer 
  tempycor                  ;; Variable to store y coordinate of inspected-farmer

 ]






;;;;;;;;;;;;;;;;;;;; INITIALIZATION PROCEDURES ;;;;;;;;;;;;;;;;;;;;


to setup                                                    ;; Setup procedure
  ;; (for this model to work with NetLogo's new plotting features,
  ;; __clear-all-and-reset-ticks should be replaced with clear-all at
  ;; the beginning of your setup procedure and reset-ticks at the end
  ;; of the procedure.)
  __clear-all-and-reset-ticks                                                 

  ifelse generate-random-seed? [
     set seed-used new-seed
  ][
  random-seed seed-used
  ]
  
  ask patches [set social-neighbors patches in-radius scope-social-influence]   ;; store patch social neighbors
  setup-farmers                                     ;; procedure to define and distribute the farmers
  setup-inspectors-educators
  my-update-plots                                              ;; plot initial state of system
end

to setup-inspectors-educators
  if debug? [show "go"]
  set number-of-inspectors inspectors
  set number-of-educators educators
  
  while [number-of-inspectors + number-of-educators > (number-of-farmers)]
   [
    if number-of-educators > 0 
     [
      set number-of-educators number-of-educators - 1
      set educators number-of-educators
     ]
    if number-of-inspectors > 0 
    [
      set number-of-inspectors number-of-inspectors - 1
      set inspectors number-of-inspectors
    ]
   ]
end

to setup-farmers                                    ;; Define the initial farmers
  if ( number-of-farmers > count patches )                  ;; Prevent that there are more farmers than patches
  [
    user-message (word "Too many farmers!")
    stop
  ]
  
  set-default-shape turtles "person"

  ask n-of number-of-farmers patches 
  [ 
    sprout-farmers 1 
    
  ]  
  
  ask farmers 
  [
    set acceptation-level random-normal acceptation 0.1     
    set farmer-state acceptation-level                      ;; Set farmers' initial state as the same value with their own acceptation level
    ]
  

  ask farmers    
  [
      set risk-aversion random-normal 0.16 0.012                         ;; Values based on data from Eisenhauer et al. (2003), Guiso et al. (2004)
      set risk-preference random-normal 0.15 0.016                  ;; Values set as such that the average is smaller than the one of risk aversion 
      ;; and the variance is larger than the variance of risk aversion. when the businiess runs well, people will be more risk-averse. 
      ;; In contrast when businiss runs poorly, people will be more risk-preferred. It was assumed that majority of farms run well normally. 
      ;; With these values, on average in 65% of the case, risk-aversion > risk-preference. 
      set grade round random-normal 3 0.5  
      set social-influential-factor random-normal Social-factor 0.1
      set mean-neighbor-state mean [farmer-state] of farmers-on social-neighbors                           
      set times-caught 0
      set total-times-caught 0
      set times-business-closure 0
      set farmer-state-memory 2
      adjust-farmer-state
      display-farmer
  ]
  
end


;;;;;;;;;;;;;;;;;;; PROCESS PROCEDURES ;;;;;;;;;;;;;;;;;;;;

;; Go procedure
to go
  
  ask patches [set pcolor black]                                 ;; Reset color of patches
  ask farmers                            
   [     
    determine-behaviour-non-compliant-farmers 
   ]
   ask farmers
   [  
    adjust-farmer-state       ;; Determine farmers' globals within correct range                       
   ]
  ask farmers 
   [                                           
    apply-social-influence
   ]
  ask farmers
   [
    determine-behaviour-unconsciously-non-compliant-farmers                                 
    if (closure-period-business > 0) [set closure-period-business closure-period-business - 1]             ;; If business had to be closed, reduce closure-period-business by 1
   ]
   ask farmers
   [
     display-farmer
  ]
  
  if inspection? ;; If the inspection switch is on, inspect farmers
  [                                               
  ; controle: er mogen niet meer inspecties gedaan worden dan er actieve farmers zijn (niet gesloten)
    let number-of-inspections 0
    ifelse number-of-inspectors > count farmers with [ closure-period-business = 0 ]
    [ set number-of-inspections count farmers with [ closure-period-business = 0 ] ]
    [ set number-of-inspections number-of-inspectors ]

    repeat number-of-inspections 
    [ 
      if debug? [show "while: go>bonus-malus (voor)"]
      select-farmer-to-inspect
      inspect-farmer
      if debug? [show "while: go>bonus-malus (na)"]
    ]
  ] 

  if education?                            ;; If the education switch is on, educate farmers
  [     ; controle: er mogen niet meer educaties gedaan worden dan er actieve farmers zijn (niet gesloten)
    let number-of-educations 0
    ifelse number-of-educators > count farmers with [ closure-period-business = 0 ]
    [ set number-of-educations count farmers with [ closure-period-business = 0 ] ]
    [ set number-of-educations number-of-educators ]
                                                 
    repeat number-of-educations 
    [
      if debug? [show "while: go>education (before)"]
      educate-farmer
      if debug? [show "while: go>education (after)"]
    ]
  ]
  
  ask patches [ if rumour > 0 [ set rumour rumour - 1]]           ;; Reduce the rumours of the patches by 1
                                                    
  my-update-plots
  tick                                                ;; One tick corresponds to running the complete model 1 time
end    

to determine-behaviour-non-compliant-farmers        
       
                                                                  
    ifelse (random-float 1 < acceptation-level or perceived-inspection-chance + perceived-business-closure-chance >= 0.01 or risk-aversion < risk-preference)   
    [
      set farmer-state farmer-state + (0.7 - (grade * 0.12))               
    ]         
    [
      set farmer-state farmer-state - (grade * 0.12)
    ]
  
  
end 

to adjust-farmer-state
  if farmer-state > 1 [set farmer-state 1]
  if farmer-state < -1 [set farmer-state -1]
  if social-influential-factor > 1 [set social-influential-factor 1]
  if social-influential-factor < 0 [set social-influential-factor 0]
  if grade > 5 [set grade 5]
  if grade < 0 [set grade 0]

  if farmer-state-memory != 2                           ;; if a farmer was unconsciously-non-compliant in the previous tick, he will adjust his state back to the state he had. See determine-behaviour-unconsciously-non-compliant-farmers.
  [
   set farmer-state farmer-state-memory
   set farmer-state-memory 2
  ]
end

 to apply-social-influence
  if social-pressure? [influence-others]
end
   
to determine-behaviour-unconsciously-non-compliant-farmers           ;; all farmers can make a mistake by accident: unconsciously-non-compliant. This is just for 1 tick and has no effect on others in the procedure social influence
   if  random-float 1 < unconsciously-non-compliant
  [  
    set farmer-state-memory farmer-state                                                               ;; error percentage
    set farmer-state -1
  ]
end

to inspect-farmer                                                    ;; Choose farmer to inspect  
 if debug? [show "inspect-farmer" ]
  ask patch tempxcor tempycor [set pcolor blue]
  ask inspected-farmer                                               ;; Check farmer-state of the inspected farm and change necessary attributes
  [
    ifelse farmer-state >= 0 
    [ if grade < 5 [set grade grade + 1] ]  ;; If the farmer is law-abiding, increase grade. Max grade = 5
      [ 
        ifelse grade > 1
        [                                                     ;; If the farmer is fraudulent and his grade > 1:
          set grade grade - 1                                 ;; Reduce grade     
          set times-caught times-caught + 1                   ;; Increase times-caught
          set total-times-caught total-times-caught + 1       ;; Increase total-times-caught --> BETER ALS WE TIMES-CAUGHT RESETTEN
        ]
        
        [                                                     ;; If the farmer is fraudulent and his grade !> 1:
           ask inspected-farmer
           [
            set closure-period-business closure-term-business                       ;; Set closure-period-business to slider level
            set times-business-closure times-business-closure + 1               ;; Count times arrested
            set farmer-state random-normal 0.1 0.3              ;; Set farmer-state to a random normal distributed level with mean 0.1 and standard deviation 0.3. 
            ;; It was assumed that the variance was larger than in the setup procedure. Some farmers will change their behaviour due to all the efforts and costs 
            ;; they had to make to open their business again. Others will remain bad. So more variance in behaviour.
            set grade 3               ;; Set grade 3: grade not very low: they are allowed to open their business again and have thus shown to be working according 
            ;;  to the rules. However, not at the max grade, as they will be kept an eye on.
            set times-caught 0                                ;; reset times-caught
           ]
        ]
      
        ask patch tempxcor tempycor [set rumour 10]           ;; Add rumour to the patch where a fraudulent farmer is found
     ]
  ]
end

to educate-farmer 

  let educated-farmer one-of farmers                          
  let tempxcor2 [xcor] of educated-farmer
  let tempycor2 [ycor] of educated-farmer
  
  let n 0
  
  while [ ( [pcolor] of patch tempxcor2 tempycor2 = blue or [pcolor] of patch tempxcor2 tempycor2 = yellow ) and n <= count farmers ] 
  [
     set educated-farmer one-of farmers                       ;; Set the patchcolor of the educated farmer to yellow (visualization purpose)   
     set tempxcor2 [xcor] of educated-farmer
     set tempycor2 [ycor] of educated-farmer
     set n n + 1
     if debug? [type "educate-farmer: loop" type n]
   ]
   
  ask patch tempxcor2 tempycor2 [set pcolor yellow]           ;; Set the patchcolor of the educated farmer to yellow (visualization purpose)

  ask educated-farmer 
   [
     if education-probability > random-float 1                ;; Not every farmer accepts education
     [ set acceptation-level acceptation-level + 0.05         ;; If education accepted, the accepation-level will increase
       set farmer-state farmer-state + (perceived-business-closure-chance + perceived-inspection-chance) ;; If educated, increase farmer-state
     ]
   ]
end

to influence-others                                           ;; Influence other farmers
  set mean-neighbor-state mean [farmer-state] of farmers-on social-neighbors
  set farmer-state mean-neighbor-state * social-influential-factor + farmer-state * (1 - social-influential-factor)
end





;;;;;;;;;;;;;;;;;;;; FUNCTIONS ;;;;;;;;;;;;;;;;;;;;

to select-farmer-to-inspect
   pick-random
   
   let p farmers with [closure-period-business = 0 and pcolor != blue]
     
   if random-float 1 < risk-based-inspection       ;; If a bad farmer is revisited  
      [ifelse any? p
      [
        set inspected-farmer one-of p with-min [grade]
        set tempxcor [xcor] of inspected-farmer 
        set tempycor [ycor] of inspected-farmer
      ]
      [
        set inspected-farmer 0
       ]
      ]
            
   if inspected-farmer = nobody or inspected-farmer = 0
    [ pick-random ]
    
    
   if inspected-farmer = nobody or inspected-farmer = 0
   [user-message "All businesses are closed or are being inspected" stop]
end

to pick-random
   if any? farmers with [closure-period-business = 0 and pcolor != blue] 
   [
     set inspected-farmer one-of farmers with [closure-period-business = 0 and pcolor != blue]
     set tempxcor [xcor] of inspected-farmer
     set tempycor [ycor] of inspected-farmer
   ]
end

to-report perceived-business-closure-chance                  ;; there is only a chance to be obliged to close the business when the grade is 1 and state < 0
  ifelse grade = 1
  [ ifelse farmer-state < 0
    [
      report detection-probability
    ]
    [
      report 0
    ]
  ]
  [
    report 0
  ]
end

to-report perceived-inspection-chance
  ifelse inspection? 
  [
    if times-caught = 0 
    [
      report (number-of-inspectors / count farmers)
    ]
  
    if times-caught > 0 
    [
      report (number-of-inspectors / count farmers) * (1 + risk-based-inspection)
    ]
  ]
  [
    report 0
  ]
end


to startup ; system procedure -- see NetLogo help
  set seed-used new-seed
end

;;;;;;;;;;;;;;;;;;;; PROCEDURES FOR DISPLAYING DATA SIMULATIONS ;;;;;;;;;;;;;;;;;;;;

;; Update plots  
to my-update-plots
  set-current-plot "Grade"
  set-current-plot-pen "Grade" 
  plot mean [Grade] of farmers
  set-current-plot "mean-farmer-state"
  set-current-plot-pen "farmer-state-pen"
  plot mean [farmer-state] of farmers
  set-current-plot "Fraudulent-farmers"
  set-current-plot-pen "fraudulent-farmers"
  plot count farmers with [farmer-state < 0]
end  
  
;; Update visuals
to display-farmer
  ifelse farmer-state >= 0
   [set color scale-color green farmer-state 1.5 -0.5]
   [set color scale-color red farmer-state -1.5 0.5]
  
  if (closure-period-business > 0) [ set color white]                                       ;; Farmers that closed their business are white
   set label grade
end
@#$#@#$#@
GRAPHICS-WINDOW
403
11
889
518
-1
-1
18.31
1
10
1
1
1
0
1
1
1
0
25
0
25
1
1
1
ticks
30.0

BUTTON
12
31
95
64
NIL
Setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
95
31
179
64
NIL
Go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
12
263
184
296
Number-of-farmers
Number-of-farmers
1
676
500
1
1
NIL
HORIZONTAL

MONITOR
896
21
1013
66
# Farmers
count farmers
17
1
11

SWITCH
11
147
190
180
Inspection?
Inspection?
1
1
-1000

SWITCH
11
180
190
213
Education?
Education?
0
1
-1000

PLOT
9
558
255
774
Grade
ticks
Grade
0.0
10.0
0.0
5.0
true
false
"" ""
PENS
"Grade" 1.0 0 -16777216 true "" ""

SLIDER
184
344
355
377
Risk-based-inspection
Risk-based-inspection
0
1
0.8
0.01
1
NIL
HORIZONTAL

MONITOR
896
73
1014
118
# Fraudulent farmers
count farmers with [farmer-state < 0]
17
1
11

MONITOR
897
126
1014
171
# Complying farmers
count farmers with [farmer-state >= 0]
17
1
11

SLIDER
12
343
184
376
Inspectors
Inspectors
0
25
6
1
1
NIL
HORIZONTAL

SWITCH
11
114
190
147
Social-pressure?
Social-pressure?
1
1
-1000

SLIDER
12
304
184
337
Scope-social-influence
Scope-social-influence
0
7
2
1
1
NIL
HORIZONTAL

MONITOR
1022
126
1141
171
# Closed businesses
count farmers with [closure-period-business > 0]
17
1
11

SLIDER
182
376
355
409
Closure-term-business
Closure-term-business
0
100
3
1
1
NIL
HORIZONTAL

SLIDER
182
418
354
451
Education-probability
Education-probability
0
1
0.5
0.01
1
NIL
HORIZONTAL

SLIDER
11
418
183
451
Educators
Educators
0
20
3
1
1
NIL
HORIZONTAL

PLOT
261
558
509
774
Mean-farmer-state
ticks
Farmer-state
0.0
10.0
-1.2
1.2
true
false
"" ""
PENS
"farmer-state-pen" 1.0 0 -16777216 true "" ""

MONITOR
1022
73
1141
118
Percentage fraudulent
100 * ((count farmers with [farmer-state < 0]) / (count farmers))
2
1
11

SLIDER
11
459
204
492
Unconsciously-non-compliant
Unconsciously-non-compliant
0
1
0.01
0.005
1
NIL
HORIZONTAL

TEXTBOX
14
10
164
31
Buttons
17
105.0
1

TEXTBOX
12
237
162
258
Settings
17
105.0
1

TEXTBOX
14
533
164
554
Output
17
105.0
1

TEXTBOX
16
91
166
112
Switches
17
105.0
1

BUTTON
179
31
263
64
Go once
Go
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

TEXTBOX
11
776
193
820
NIL
9
0.0
1

SWITCH
190
114
380
147
Debug?
Debug?
1
1
-1000

PLOT
514
558
763
774
Fraudulent-farmers
ticks
Number of fraudulent-farmers
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"fraudulent-farmers" 1.0 0 -16777216 true "" ""

SLIDER
183
263
355
296
Acceptation
Acceptation
0
1
0.6
0.01
1
NIL
HORIZONTAL

SLIDER
12
376
184
409
Detection-probability
Detection-probability
0
1
0.1
0.05
1
NIL
HORIZONTAL

SLIDER
187
304
360
337
social-factor
social-factor
0
1
0.6
0.01
1
NIL
HORIZONTAL

SWITCH
190
148
380
181
Generate-random-seed?
Generate-random-seed?
0
1
-1000

INPUTBOX
191
179
380
239
seed-used
494848306
1
0
Number

@#$#@#$#@
## WHAT IS IT?

This model has been devised for Rikilt/VWA, the Dutch Food Safety Authority, to show the effects of different strategies for compliance-enforcement. Authorities are interested in apply risk-based inspection strategies to increase the effectiveness of law-enforcement in the pig-farm production relating to the use of anti-biotics.

## HOW IT WORKS

Environment "farmland": Each farm has its own patch in the vicinity of other farmers. 

Agents "farmers": Each round farmers have the ability to be "better" or "worse", based on their environment and their own risk-attitude.

Procedure "inspectors": At each round, inspectors randomly and systematically test farmers whether they are abiding the laws. If not, the farmer will get a grade lower.  
When a farmer reaches the grade of 0, he is suspended from economic activity for a jail-period of n-ticks.

Procedure "educators": Farmers have the opportunity to be educated and by doing so increase their level of "being good". Educators choose at-random who to educated and farmers are rondomly perceptible to education.

## HOW TO USE IT

First press "setup" to initialize the model parameters. After setup, just press "go" and observe the changes in the system. Please slide the speed-slide (NetLogo control) to "slower" to see a good visualization of changes happening to the system.

## THINGS TO TRY

There are two interesting states of the system.

HYSTERESIS: Turn all settings to: number-of-farmers 500, vision 3, social-state-influence? on, inspection? on, education? off, inspectors 11, educators 0, imitation-probability 1.0, education-probability 0.0, bad-farmer-revisit-chance 0.0, error-percentage 0.09, jail-duration 10.

Slide the inspectors from 11 step by step to 0. A slow diminish in farmer state will show. Now slide the inspectors back from 0 to 11. The farmers' states do not correspond immediately and will show slow recovery. This lag is called hysteresis.

PHASE-TRANSITIONS: Turn all settings to: number-of-farmers 500, vision 3, social-state-influence? on, inspection? on, education? off, inspectors 11, educators 0, imitation-probability 1.0, education-probability 0.0, bad-farmer-revisit-chance 0.0, error-percentage 0.09, jail-duration 10.

Slide the error-percentage from 0.090 to 0.015 and observe that farmers' states do not converge to a stable point but constantly change from law-abiding to fraudult, without settle on either one.

## EXTENDING THE MODEL

This model lacks the layered structure of public and private compliance mechanisms as they exist in the Dutch pig-farming regulation realm. An extentions to this model might thus be to add an extra layer of authorities that communicate with the current inspectors. Doing so gives the possibility to explore an even greater range of compliance testing strategies.

## RELATED MODELS

One model that has been used as a reference and inspiration point has been the Rebellion-model in the model library (Sample models > Social Science > Rebellion).

## CREDITS AND REFERENCES

Credits go to Uri Wilensky for providing his Rebellion model for us to examinate and built upon our model. Our model has been built in cooperation with Rikilt/VWA, the Dutch Food Safety Authority, Wageningen, thanks to Esther van Asselt and Piet van Sterrerburg.

We are:

Nicoline Lustig (nicoline.lustig@wur.nl)  
Frans Boogaard (frans.boogaard@wur.nl)  
Nabi Abudaldah (nabi.abudaldah@wur.nl)

Wageningen University  
February 2011

With help of our teachers:

Gertjan Hofstede  
Mark Kramer  
Sjoukje Osinga
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

person farmer
false
0
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Polygon -1 true false 60 195 90 210 114 154 120 195 180 195 187 157 210 210 240 195 195 90 165 90 150 105 150 150 135 90 105 90
Circle -7500403 true true 110 5 80
Rectangle -7500403 true true 127 79 172 94
Polygon -13345367 true false 120 90 120 180 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 180 90 172 89 165 135 135 135 127 90
Polygon -6459832 true false 116 4 113 21 71 33 71 40 109 48 117 34 144 27 180 26 188 36 224 23 222 14 178 16 167 0
Line -16777216 false 225 90 270 90
Line -16777216 false 225 15 225 90
Line -16777216 false 270 15 270 90
Line -16777216 false 247 15 247 90
Rectangle -6459832 true false 240 90 255 300

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
0
Rectangle -7500403 true true 151 225 180 285
Rectangle -7500403 true true 47 225 75 285
Rectangle -7500403 true true 15 75 210 225
Circle -7500403 true true 135 75 150
Circle -16777216 true false 165 76 116

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

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270

@#$#@#$#@
NetLogo 5.0.3
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="Artikel Base Case" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="36"/>
    <metric>count farmers with [farmer-state &lt; 0] / count farmers</metric>
    <enumeratedValueSet variable="Education?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Social-pressure?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Inspection?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Debug?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Number-of-farmers">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Acceptation">
      <value value="0.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Scope-social-influence">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="social-factor">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Inspectors">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Risk-based-inspection">
      <value value="0.8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Detection-probability">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Closure-term-business">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Educators">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Education-probability">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Unconsciously-non-compliant">
      <value value="0.01"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Artikel Scenario 1" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="36"/>
    <metric>count farmers with [farmer-state &lt; 0] / count farmers</metric>
    <enumeratedValueSet variable="Education?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Social-pressure?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Inspection?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Debug?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Number-of-farmers">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Acceptation">
      <value value="0"/>
      <value value="0.2"/>
      <value value="0.4"/>
      <value value="0.6"/>
      <value value="0.8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Scope-social-influence">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="social-factor">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Inspectors">
      <value value="2"/>
      <value value="4"/>
      <value value="6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Risk-based-inspection">
      <value value="0.8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Detection-probability">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Closure-term-business">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Educators">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Education-probability">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Unconsciously-non-compliant">
      <value value="0.01"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Artikel Scenario 2" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="36"/>
    <metric>count farmers with [farmer-state &lt; 0] / count farmers</metric>
    <enumeratedValueSet variable="Education?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Social-pressure?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Inspection?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Debug?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Number-of-farmers">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Acceptation">
      <value value="0"/>
      <value value="0.2"/>
      <value value="0.4"/>
      <value value="0.6"/>
      <value value="0.8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Scope-social-influence">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="social-factor">
      <value value="0.1"/>
      <value value="0.3"/>
      <value value="0.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Inspectors">
      <value value="4"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Risk-based-inspection">
      <value value="0.8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Detection-probability">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Closure-term-business">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Educators">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Education-probability">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Unconsciously-non-compliant">
      <value value="0.01"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Artikel Scenario 3" repetitions="100" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="36"/>
    <metric>count farmers with [farmer-state &lt; 0] / count farmers</metric>
    <enumeratedValueSet variable="Education?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Social-pressure?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Inspection?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Debug?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Number-of-farmers">
      <value value="500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Acceptation">
      <value value="0.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Scope-social-influence">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="social-factor">
      <value value="0.1"/>
      <value value="0.3"/>
      <value value="0.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Inspectors">
      <value value="2"/>
      <value value="4"/>
      <value value="6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Risk-based-inspection">
      <value value="0.8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Detection-probability">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Closure-term-business">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Educators">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Education-probability">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Unconsciously-non-compliant">
      <value value="0.01"/>
    </enumeratedValueSet>
  </experiment>
</experiments>
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 1.0 0.0
0.0 1 1.0 0.0
0.2 0 1.0 0.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180

@#$#@#$#@
0
@#$#@#$#@
