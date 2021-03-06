{-# LANGUAGE FlexibleContexts      #-}
{-# LANGUAGE LambdaCase            #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE ScopedTypeVariables   #-}
module Api.Package.Report
  ( WithReport
  , resource
  , readReport
  ) where

import           Control.Monad.Except
import           Control.Monad.Reader
import           Data.Aeson
import           Data.String.Conversions
import           Path
import           Rest
import qualified Rest.Resource           as R

import           Api.Package             (validatePackage)
import           Api.Types
import           Config
import           Paths

data ReportIdentifier = Latest

type WithReport = ReaderT ReportIdentifier WithPackage

resource :: Resource WithPackage WithReport ReportIdentifier Void Void
resource = mkResourceReader
  { R.name   = "report"
  , R.schema = noListing $ named [("latest", single Latest)]
  , R.get    = Just get
  }

get :: Handler WithReport
get = mkConstHandler jsonO handler
  where
    handler :: ExceptT Reason_ WithReport ShallowReport
    handler = do
      pn <- lift . lift $ ask
      ident <- ask
      case ident of
        Latest -> byName pn
    byName :: PackageName -> ExceptT Reason_ WithReport ShallowReport
    byName pkgName = do
      validatePackage pkgName
      readShallowReport pkgName `orThrow` NotFound

readShallowReport :: (MonadIO m, MonadConfig m) => PackageName -> m (Maybe ShallowReport)
readShallowReport pkgName =
  fmap ((\(t,c) -> toShallowReport t <$> decode c) =<<)
    .  liftIO
    .  (\repDir -> tryReadFileWithModifiedTime
              <=< fmap (repDir </>) . (<.> "json")
              <=< parseRelFile . cs $ pkgName
       )
   =<< asksConfig reportDir

readReport :: (MonadIO m, MonadConfig m) => PackageName -> m (Maybe Report)
readReport pkgName =
  fmap ((\(t,c) -> toReport t <$> decode c) =<<)
    .  liftIO
    .  (\repDir -> tryReadFileWithModifiedTime
              <=< fmap (repDir </>) . (<.> "json")
              <=< parseRelFile . cs $ pkgName
       )
   =<< asksConfig reportDir
