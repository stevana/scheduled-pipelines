module Main (main) where

import Test.Tasty
import Test.Tasty.HUnit

import LibTest

------------------------------------------------------------------------

tests :: TestTree
tests = testGroup "Tests"
  [ testCaseBool "OneStageOneWorker"   unit_oneStageOneWorker
  , testCaseBool "OneStageTwoWorkers"  unit_oneStageTwoWorkers
  , testCaseBool "TwoStagesTwoWorkers" unit_twoStagesTwoWorkers
  ]

testCaseBool :: String -> IO Bool -> TestTree
testCaseBool name assertion =
  localOption (mkTimeout 1000000) $
    testCase name (assertBool name =<< assertion)

main :: IO ()
main = defaultMain tests
