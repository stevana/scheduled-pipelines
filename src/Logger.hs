{-# LANGUAGE OverloadedStrings #-}

module Logger where

import Control.Monad
import Data.List (intersperse)
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.Lazy as LazyText
import qualified Data.Text.IO as Text
import qualified Data.Text.Lazy.Builder as Builder
import System.IO
import System.Exit

------------------------------------------------------------------------

data Logger = Logger
  { _log :: LogLevel -> [LogSegment] -> IO () }

data LogLevel = Trace | Debug | Info | Warn | Error | Fatal
  deriving (Eq, Ord, Show, Enum, Bounded)

data LogSegment 
  = Text Text 
  | String String 
  | Int Int

------------------------------------------------------------------------

ppLogLevel :: LogLevel -> Text
ppLogLevel lvl = "[" <> Text.toLower (Text.pack (show lvl)) <> "]"

ppLogSegments :: [LogSegment] -> Text
ppLogSegments 
  = LazyText.toStrict 
  . Builder.toLazyText 
  . mconcat
  . intersperse (Builder.singleton ' ') 
  . map aux
  where
    aux (Text t)   = Builder.fromText t
    aux (String s) = Builder.fromString s
    aux (Int i)    = Builder.fromString (show i)

defaultFormatter :: LogLevel -> [LogSegment] -> Text
defaultFormatter lvl segs = ppLogLevel lvl <> " " <> ppLogSegments segs

------------------------------------------------------------------------

data LoggerOptions = LoggerOptions 
  { _loggerKind      :: LoggerKind
  , _loggerFilter    :: LoggerFilter
  , _loggerTimestamp :: Maybe (IO Text) -- XXX: add later
  }

defaultLoggerOptions :: LoggerOptions
defaultLoggerOptions = LoggerOptions StdoutLogger noLoggerFilter Nothing

data LoggerKind = NoLogger | StdoutLogger | FileLogger FilePath
  deriving (Show, Read)

type LoggerFilter = [LogLevel]

noLoggerFilter :: LoggerFilter
noLoggerFilter = enumFrom minBound

newLogger :: LoggerOptions -> IO Logger
newLogger opts = case _loggerKind opts of
  NoLogger      -> return noLogger
  StdoutLogger  -> return stdoutLogger
  FileLogger fp -> fileLogger fp
  where
    levelFilter lvl io = when (lvl `elem` _loggerFilter opts) io

    noLogger :: Logger
    noLogger = Logger (\_ _ -> return ())

    stdoutLogger :: Logger
    stdoutLogger = Logger 
      { _log = \lvl segs -> levelFilter lvl $
                              Text.putStrLn (defaultFormatter lvl segs) 
      }

    fileLogger :: FilePath -> IO Logger
    fileLogger fp = withFile fp AppendMode $ \h -> 
      return Logger 
        { _log = \lvl segs -> levelFilter lvl $
                                Text.hPutStrLn h (defaultFormatter lvl segs)
        }

------------------------------------------------------------------------

trace :: Logger -> [LogSegment] -> IO ()
trace l = _log l Trace

debug :: Logger -> [LogSegment] -> IO ()
debug l = _log l Debug

info :: Logger -> [LogSegment] -> IO ()
info l = _log l Info

warn :: Logger -> [LogSegment] -> IO ()
warn l = _log l Warn

error :: Logger -> [LogSegment] -> IO ()
error l = _log l Error
-- XXX: call error?

fatal :: Logger -> [LogSegment] -> IO ()
fatal l segs = do
  _log l Fatal segs
  exitFailure
