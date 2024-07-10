module Main (main) where

import Test.Tasty
import Test.Tasty.HUnit

import LibTest

------------------------------------------------------------------------

tests :: TestTree
tests = testGroup "Tests"
  [ testCaseBool "TwoStagePipeline" unit_twoStagePipeline ]

testCaseBool :: String -> IO Bool -> TestTree
testCaseBool name assertion = 
  localOption (mkTimeout 1000000) $
    testCase name (assertBool name =<< assertion)

main :: IO ()
main = defaultMain tests
