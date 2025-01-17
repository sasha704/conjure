{-# LANGUAGE DeriveGeneric, DeriveDataTypeable, DeriveFunctor, DeriveTraversable, DeriveFoldable #-}

module Conjure.Language.Expression.Op.Apart where

import Conjure.Prelude
import Conjure.Language.Expression.Op.Internal.Common

import qualified Data.Aeson as JSON             -- aeson
import qualified Data.HashMap.Strict as M       -- unordered-containers
import qualified Data.Vector as V               -- vector


data OpApart x = OpApart x x
    deriving (Eq, Ord, Show, Data, Functor, Traversable, Foldable, Typeable, Generic)

instance Serialize x => Serialize (OpApart x)
instance Hashable  x => Hashable  (OpApart x)
instance ToJSON    x => ToJSON    (OpApart x) where toJSON = genericToJSON jsonOptions
instance FromJSON  x => FromJSON  (OpApart x) where parseJSON = genericParseJSON jsonOptions

instance (TypeOf x, Pretty x) => TypeOf (OpApart x) where
    typeOf inp@(OpApart x p) = do
        xTy <- typeOf x
        pTy <- typeOf p
        case (xTy, pTy) of
            (TypeSet xTyInner, TypePartition pTyInner) | typesUnify [xTyInner, pTyInner] -> return TypeBool
            _ -> raiseTypeError inp

instance SimplifyOp OpApart x where
    simplifyOp _ = na "simplifyOp{OpApart}"

instance Pretty x => Pretty (OpApart x) where
    prettyPrec _ (OpApart a b) = "apart" <> prettyList prParens "," [a,b]

instance VarSymBreakingDescription x => VarSymBreakingDescription (OpApart x) where
    varSymBreakingDescription (OpApart a b) = JSON.Object $ M.fromList
        [ ("type", JSON.String "OpApart")
        , ("children", JSON.Array $ V.fromList
            [ varSymBreakingDescription a
            , varSymBreakingDescription b
            ])
        ]
