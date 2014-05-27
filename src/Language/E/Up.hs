{-# LANGUAGE OverloadedStrings  #-}
module Language.E.Up(translateSolution,translateSolution',translateSolutionM) where

import Language.E

import Language.E.Pipeline.ReadIn(writeSpec)

translateSolution
    :: EssenceFP
    -> Maybe EssenceParamFP
    -> EprimeFP
    -> Maybe EprimeParamFP
    -> EprimeSolutionFP
    -> EssenceSolutionFP  --Output
    -> IO ()
translateSolution
    essence param eprime eprimeParam eprimeSolution outSolution =
    translateSolution' essence param eprime eprimeParam eprimeSolution
    >>= writeSpec outSolution
    >>  return ()

translateSolution'
    :: EssenceFP
    -> Maybe EssenceParamFP
    -> EprimeFP
    -> Maybe EprimeParamFP
    -> EprimeSolutionFP
    -> IO EssenceSolution 
translateSolution' = undefined


type Essence   = Spec
type Eprime    = Spec
type ESolution = Spec
type Param = Spec
type EssenceParam = Spec

translateSolutionM
  :: Monad m =>
  Essence
  -> Maybe EssenceParam
  -> Eprime
  -> Maybe Param
  -> ESolution
  -> [Text]
  -> m Spec
translateSolutionM = undefined

type EssenceSolution = Spec

type EssenceFP         = FilePath
type EprimeFP          = FilePath
type EssenceParamFP    = FilePath
type EprimeParamFP     = FilePath
type EprimeSolutionFP  = FilePath
type EssenceSolutionFP = FilePath

