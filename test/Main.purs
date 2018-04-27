module Test.Main where

import Prelude

import Control.Monad.Eff (Eff)
import Control.Monad.Eff.Console (CONSOLE, log)
import Control.Monad.Eff.Exception (throw, EXCEPTION)
import Data.Argonaut (jsonParser)
import Data.Array as Array
import Data.Array.NonEmpty (NonEmptyArray)
import Data.Array.NonEmpty as NonEmptyArray
import Data.Either (Either, either)
import Data.Foldable (for_)
import Data.Maybe (isJust)
import Data.String (stripPrefix, Pattern(..))
import ExternsCheck (UnsuitableReason, checkEntryPoint, defaultOptions, exportedValues)
import Node.Encoding (Encoding(UTF8))
import Node.FS (FS)
import Node.FS.Sync (readTextFile)

type EffT = Eff (console :: CONSOLE, exception :: EXCEPTION, fs :: FS)

main :: EffT Unit
main = do
  externsStr <- readTextFile UTF8 "./output/Test.Sample/externs.json"
  externs <- either throw pure $ jsonParser externsStr

  let cases = exportedValues externs

  log "Passing cases:"
  for_ (Array.filter isOk cases) \c -> do
    log ("  " <> c)
    shouldSucceed (checkEntryPoint (defaultOptions { mainName = c }) externs)

  log "Failing cases:"
  for_ (Array.filter isNotOk cases) \c -> do
    let v = checkEntryPoint (defaultOptions { mainName = c }) externs
    log ("  " <> c <> ":")
    log ("    " <> show v)
    shouldFail v

  log "Nonexistent entry point:"
  do
    let c = "nonexistent"
    let v = checkEntryPoint (defaultOptions { mainName = c }) externs
    log ("  " <> c <> ":")
    log ("    " <> show v)
    shouldFail v

  where
  isOk = isJust <<< stripPrefix (Pattern "ok")
  isNotOk = isJust <<< stripPrefix (Pattern "notok")

shouldSucceed :: Either (NonEmptyArray UnsuitableReason) Unit -> EffT Unit
shouldSucceed =
  either (\errs -> throw ("Expected no errors, got " <> show errs)) pure

shouldFail :: Either (NonEmptyArray UnsuitableReason) Unit -> EffT Unit
shouldFail =
  either (\_ -> pure unit) (\_ -> throw "Expected errors, got none")

shouldFailWith :: NonEmptyArray UnsuitableReason -> Either (NonEmptyArray UnsuitableReason) Unit -> EffT Unit
shouldFailWith exp =
  either (\act -> when (exp `differentFrom` act)
                       (throw ("Expected " <> show exp <> ", got " <> show act)))
         (\_ -> (throw "Expected errors, got none"))

  where
  differentFrom xs ys = NonEmptyArray.sort xs /= NonEmptyArray.sort ys
