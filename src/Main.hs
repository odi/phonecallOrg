{-# LANGUAGE DeriveDataTypeable #-}
module Main where

-- TODO: description which program will be used
-- TODO: date should be <from>--<to>
-- TOOD: rename file to phonecallOrg
-- TODO: extract all timestamps

import Text.XML.Light
import Data.Maybe
import Data.Time
import Data.List
import System.Console.CmdArgs

-- | Datatype for call-type.
-- It is only interessting from- and to-calls.
data CallType = CallFrom | CallTo | CallNone
              deriving Eq
                       
instance Show CallType where
  show (CallFrom) = "from"
  show (CallTo)   = "to"
  show (CallNone) = ""

-- | Main datatype for a call.
data Call = Call
  { cPhone     :: String     -- ^ phone number
  , cType      :: CallType   -- ^ call type (1..from, 2..to)
  , cStartDate :: LocalTime  -- ^ timestamp of call, neccessary??
  , cDate      :: Int        -- ^ timestamp of call ('%s')
  , cDuration  :: Int        -- ^ duration of call in seconds
  , cName      :: String     -- ^ name of person from phone's contact list
  } deriving Show

instance Eq Call where
  (==) c1 c2 = (cDate c1) == (cDate c2)

instance Ord Call where
  compare c1 c2 = compare (cDate c1) (cDate c2)
  (<=) c1 c2    = (cDate c1) <= (cDate c2)

type BackupFilePath = FilePath  -- ^ file-path for backup-file
type InputFilePath  = FilePath  -- ^ file-path for input-file
type OutputFilePath = FilePath  -- ^ file-path for output-file

-- | Creates an org-mode Entry.
orgEntry :: TimeZone -> Call -> String
orgEntry tz c = prefix ++ (show $ cType c) ++ " " ++ linkName ++ "\n" ++ props
  where
    convTime = formatTime defaultTimeLocale orgmodeTimeFormat
    timeH = convTime (cStartDate c) ++ "--" ++ convTime (addSeconds tz (cDuration c) (cStartDate c))
    prefix = "* call "
    linkName = concat ["[[contact:", (cName c), "][", (cName c), "]]"]
    props = concat [ "  :PROPERTIES:\n"
                   , "  :DATE:     ", timeH, "\n"
                   , "  :DURATION: ", show $ cDuration c, "s\n"
                   , "  :PHONE:    ", (cPhone c), "\n"
                   , "  :END:\n"
                   ]

-- | Extract all Call's from XML-Content.
calls :: [Content] -> [Call]
calls content = map (convertElement)
                (concatMap (findElements $ (qname "call")) $ onlyElems content)

-- | Converts an XML-Element to a Call
convertElement :: Element -> Call
convertElement e = Call number typ startDate date duration name
  where
    number    = fromMaybe "" $ findAttr (qname "number") e
    typ       = case (fromMaybe "" $ findAttr (qname "type") e) of
      "1"       -> CallFrom
      "2"       -> CallTo
      otherwise -> CallNone
    startDate = parseTimeOrError True defaultTimeLocale "%e %b %Y %T"
                (fromMaybe "0" $ findAttr (qname "readable_date") e)
    duration  = read (fromMaybe "0" $ findAttr (qname "duration") e) :: Int
    name      = fromMaybe "Unknown" $ findAttr (qname "contact_name") e
    date      = read (fromMaybe "0" $ findAttr (qname "date") e) :: Int

diffDates :: LocalTime -> LocalTime -> TimeZone -> NominalDiffTime
diffDates t1 t2 tz = diffUTCTime (ltUTC t1) (ltUTC t2)
  where ltUTC t = localTimeToUTC tz t

addSeconds :: Integral a => TimeZone -> a -> LocalTime -> LocalTime
addSeconds tz s t = utcToLocalTime tz $ addUTCTime (fromIntegral s) (localTimeToUTC tz t)

qname :: String -> QName
qname s = QName s Nothing Nothing

-- | Write's one Call to the given file.
-- It will write only that calls which are either newer than the last phone-call
-- from the last time where this program was called nor the type of the call is
-- not `CallNone'.
writeCall :: Bool -> BackupFilePath -> OutputFilePath -> Call -> IO ()
writeCall complete bfp ofp c = case (cType c) of
  CallNone  -> return () -- dont write call without defined type to file
  otherwise -> do
    timezone  <- getCurrentTimeZone
    timestamp <- if (complete) then return "1970-01-01 00:00:00" else readFile bfp
    let ts = parseTime_ timestamp
    if ((diffDates (convTime (cStartDate c)) ts timezone) > 0)
      then appendFile ofp (orgEntry timezone c)
      else return ()
  where
    convTime = parseTime_ . formatTime_

-- | Write all calls to file.
writeCalls :: Bool -> BackupFilePath -> OutputFilePath -> [Call] -> IO ()
writeCalls complete bfp ofp cs = do
  let cs' = sort cs
  mapM_ (writeCall complete bfp ofp) cs'
  writeFile bfp (formatTime_ $ cStartDate (last cs'))
  
data CArgs = CArgs
  { complete   :: Bool       -- ^ flag for writting complete file or only append
  , inputFile  :: FilePath   -- ^ filepath to input file
  , outputFile :: FilePath   -- ^ filepath to output file
  } deriving (Show, Data, Typeable)

cargs = CArgs { complete = def
              , inputFile = "/mnt/phone/calls.xml" &= opt ""
              , outputFile = "/home/odi/wiki/Phone.org" &= opt ""
              } &= program "phonecallOrg" &= summary ""

parseTime_ :: String -> LocalTime
parseTime_ = parseTimeOrError True defaultTimeLocale workingTimeFormat

formatTime_ :: LocalTime -> String
formatTime_ = formatTime defaultTimeLocale workingTimeFormat

workingTimeFormat = "%Y-%m-%d %T"
orgmodeTimeFormat = "<%Y-%m-%d %a %T>"

main :: IO ()
main = do
  args <- cmdArgs cargs
  
  let iF = inputFile args
      oF = outputFile args
      bF = "/home/odi/.parseBackup"

  f <- readFile iF
  let c = calls $ parseXML f

  writeCalls (complete args) bF oF c
  
  return ()
