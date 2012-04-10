(list 
   (cons 'parameterManager
      (make-instance 'ParameterManager
         #:fixedParam #f
         #:cycleLimit 200
         #:showLiveData #f
         #:showLiveAgg #f
         #:monteCarloRuns 70
         #:currentRun 0
         #:runFileNameBase run
         #:similarityMeasure global_sd
         #:nominalProfile dat
         #:experimentalProfile art
         #:artStepsPerCycle 2
         #:artGraphInputFile ""
         #:artGraphSpecFile jpet301
         #:artGraphSpecIterates 1
         #:artDirSinRatio 0.55F0
         #:artTortSinRatio 0.45F0
         #:artDirSinCircMin 24
         #:artDirSinCircMax 24
         #:artDirSinLenAlpha 1.0F0
         #:artDirSinLenBeta 0.085F0
         #:artDirSinLenShift 0.0F0
         #:artTortSinCircMin 10
         #:artTortSinCircMax 10
         #:artTortSinLenAlpha 8.0F0
         #:artTortSinLenBeta 0.075F0
         #:artTortSinLenShift -10.0F0
         #:artSSpaceScale 1
         #:artESpaceScale 1
         #:artDSpaceScale 1
         #:artSinusoidTurbo  0.25D0
         #:artCoreFlowRate 1
         #:artBileCanalCirc 1
         #:artS2EJumpProb 0.85F0
         #:artE2SJumpProb 0.15F0
         #:artE2DJumpProb 0.85F0
         #:artD2EJumpProb 0.15F0
         #:artECDensity 0.90F0
         #:artHepDensity 0.90F0
         #:artBindersPerCellMin 125
         #:artBindersPerCellMax 125
         #:artMetabolismProb 0.20F0 
         #:artEnzymeInductionWindow 500
         #:artEnzymeInductionThreshold 10
         #:artEnzymeInductionRate 0.00F0
         #:artSoluteBindingProb 0.75F0
         #:artSoluteBindingCycles 15
         #:artSoluteScale 1.0D0
         #:artViewDetails 1
         #:artSnapshotsOn #f
         #:refTimeStart 7.0D0
         #:refTimeIncrement 0.1D0
         #:ref_k1 0.03D0
         #:ref_k2 0.01D0
         #:ref_ke 0.1D0
         #:refDispersionNum 0.265D0
         #:refExpTransitTime 6.35D0
         #:refBolusMass 1.0D0
         #:refPerfusateFlow 0.312D0
         #:refMainDivertRatio 0.00654D0
         #:refSecDivertRatio 0.0248D0
         #:refEpsilon 0.000000000000000000000001D0
         #:datInterpolate #t
         #:datFileName jpet301-fig1.csv
         ))
   (cons 'bolusContents 
      (make-instance 'Map 
         (cons 
            (make-instance 'Tag  
               #:myName (make-instance 'String "Compound")
               #:properties (make-instance 'Map 
                               (cons (make-instance 'String  "membraneCrossing") 
                                  (make-instance 'String  "YES")) 
                               (cons (make-instance 'String  "numBufferSpaces") 
                                  (make-instance 'Integer  #:value 0))
                               (cons (make-instance 'String "bufferDelay")
                                  (make-instance 'Integer  #:value 0))
                               (cons (make-instance 'String "bileRatio")
                                  (make-instance 'Double #:val 0.5D0))
                               )) 
            (make-instance 'Double  #:val 0.500000D0))
         (cons
            (make-instance 'Tag
               #:myName (make-instance 'String  "Marker")
               #:properties (make-instance 'Map
                               (cons (make-instance 'String  "membraneCrossing")
                                  (make-instance 'String  "NO"))
                               (cons (make-instance 'String  "numBufferSpaces")
                                  (make-instance 'Integer #:value 0))
                               (cons (make-instance 'String "bufferDelay")
                                  (make-instance 'Integer  #:value 0))
                               (cons (make-instance 'String "bileRatio")
                                  (make-instance 'Double #:val 0.0D0))
                               ))
            (make-instance 'Double  #:val 0.500000D0))
         (cons
            (make-instance 'Tag
               #:myName (make-instance 'String  "Metabolite")
               #:properties (make-instance 'Map
                               (cons (make-instance 'String  "membraneCrossing")
                                  (make-instance 'String  "YES"))
                               (cons (make-instance 'String  "numBufferSpaces")
                                  (make-instance 'Integer #:value 0))
                               (cons (make-instance 'String "bufferDelay")
                                  (make-instance 'Integer  #:value 0))
                               (cons (make-instance 'String "bileRatio")
                                  (make-instance 'Double #:val 0.0D0))
                               ))
            (make-instance 'Double  #:val 0.000000D0))
         )
      )
   (cons 'dosageParams
      (make-instance 'Array
         (make-instance 'Integer #:value 5000)
         (make-instance 'Integer #:value -1)    ; < 0 means use impulse
         (make-instance 'Integer #:value -2)))  ; < 0 means use impulse
   (cons 'dosageTimes
      (make-instance 'Array  
         (make-instance 'Integer  #:value 2)))
   )
