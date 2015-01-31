{-# LANGUAGE FlexibleContexts #-}

module Conjure.Representations
    ( downD, downC, up
    , downD1, downC1, up1
    , downToX1
    , reprOptions, getStructurals
    , downX1
    ) where

-- conjure
import Conjure.Bug
import Conjure.Prelude
import Conjure.Language.Definition
import Conjure.Language.Type
import Conjure.Language.Ops
import Conjure.Language.TypeOf
import Conjure.Language.Pretty
import Conjure.Representations.Combined


-- | Refine (down) an expression (X), one level (1).
downX1 :: MonadFail m => Expression -> m [Expression]
downX1 (Constant x) = onConstant x
downX1 (AbstractLiteral x) = onAbstractLiteral x
downX1 (Reference x (Just refTo)) = onReference x refTo
downX1 (Op x) = onOp x
downX1 x@WithLocals{} = fail ("downX1:" <++> pretty (show x))
downX1 x = bug ("downX1:" <++> pretty (show x))

onConstant :: MonadFail m => Constant -> m [Expression]
onConstant (ConstantAbstract (AbsLitTuple xs)) = return (map Constant xs)
onConstant (ConstantAbstract (AbsLitMatrix index xs)) = do
    yss <- mapM (downX1 . Constant) xs
    let indexX = fmap Constant index
    return [ AbstractLiteral (AbsLitMatrix indexX ys) | ys <- transpose yss ]
onConstant x = bug ("downX1.onConstant:" <++> pretty (show x))

onAbstractLiteral :: MonadFail m => AbstractLiteral Expression -> m [Expression]
onAbstractLiteral (AbsLitTuple xs) = return xs
onAbstractLiteral (AbsLitMatrix index xs) = do
    yss <- mapM downX1 xs
    return [ AbstractLiteral (AbsLitMatrix index ys) | ys <- transpose yss ]
onAbstractLiteral x = bug ("downX1.onAbstractLiteral:" <++> pretty (show x))

onReference :: MonadFail m => Name -> ReferenceTo -> m [Expression]
onReference nm refTo =
    case refTo of
        Alias x                   -> downX1 x
        InComprehension{}         -> fail ("downX1.onReference.InComprehension:" <++> pretty (show nm))
        DeclNoRepr{}              -> fail ("downX1.onReference.DeclNoRepr:"      <++> pretty (show nm))
        DeclHasRepr forg _ domain -> downToX1 forg nm domain

onOp :: MonadFail m => Ops Expression -> m [Expression]
onOp p@(MkOpIndexing (OpIndexing m i)) = do
    ty <- typeOf m
    case ty of
        TypeMatrix{} -> return ()
        _ -> fail $ "[onOp, not a TypeMatrix]" <+> vcat [pretty ty, pretty p]
    xs <- downX1 m
    let iIndexed x = Op (MkOpIndexing (OpIndexing x i))
    return (map iIndexed xs)
onOp op = fail ("downX1.onOp:" <++> pretty op)