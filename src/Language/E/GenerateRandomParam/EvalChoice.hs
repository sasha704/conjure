{-# OPTIONS_GHC -fno-warn-incomplete-patterns #-}
{-# OPTIONS_GHC -fno-warn-incomplete-uni-patterns #-}
{-# LANGUAGE QuasiQuotes, ViewPatterns, OverloadedStrings #-}
module Language.E.GenerateRandomParam.EvalChoice(evalChoice,allChoices,permutationsN) where

import Language.E
import Language.E.GenerateRandomParam.Data
import Language.E.GenerateRandomParam.Common(countRanges,countRange)
import Language.E.Up.Debug(upBug)

import Control.Arrow((&&&))

import Data.Set (Set)
import Data.List(genericTake,genericDrop, genericSplitAt)
import Data.Map (Map)

import qualified Data.Set as Set
import qualified Data.Map as M

--import Text.Groom(groom)

-- Converts a choice into an action
evalChoice :: (MonadConjure m, RandomM m) => Choice -> m E

evalChoice (CBool) = do
    index <- rangeRandomM (0, 1)
    return $ Tagged "value" [Tagged "literal" [Prim (B (index == 1) )]]

evalChoice (CInt size ranges) = do
    index <- rangeRandomM (0, fromIntegral size-1)
    let n = pickIth (toInteger index) ranges
    mkLog "IntData" $  sep ["Index:"  <+> pretty index
                        ,"Ranges:" <+> (pretty . show) ranges
                        ,"Picked"  <+> pretty n]
    return [xMake| value.literal := [Prim (I n )] |]

evalChoice (CEnum _ range enums) = do
    index <- rangeRandomM (getNums range)
    return $ enums !! index
    where
    getNums :: Range -> (Int,Int)
    getNums (RSingle n)  = (fromIntegral n,fromIntegral n)
    getNums (RRange a b) = (fromIntegral a, fromIntegral b)


evalChoice (CTuple doms) = do
    vals <- mapM evalChoice doms
    return $ [xMake| value.tuple.values :=  vals |]

evalChoice (CSet sizeRange dom) = do
    size <- evalRange sizeRange
    es <- findDistinct' (evalChoice dom) Set.empty size
    return [xMake| value.set.values := (es) |]

evalChoice (CMatrix sizeRange dom) = do
    let size  = sum . map countRange $ sizeRange
    vals     <- mapM evalChoice (genericTake size . repeat $ dom)
    return $ [xMake| value.matrix.values := vals
                   | value.matrix.indexrange.domain.int.ranges := indexRanges |]

    where
    indexRanges = map rangeToIndexRange sizeRange
    rangeToIndexRange :: Range -> E
    rangeToIndexRange (RSingle i)  = [xMake| range.single.value.literal := [Prim (I i) ] |]
    rangeToIndexRange (RRange a b) =
        [xMake| range.fromTo := map wrap [a,b] |]
    wrap i = [xMake| value.literal := [Prim (I i)]  |]

evalChoice (CRel sizeRange doms) = do
    size <- evalRange sizeRange
    es <- findDistinct' (mapM evalChoice doms) Set.empty size
    return $ [xMake| value.relation.values := (map wrap es) |]

    where
    wrap :: [E] -> E
    wrap vs = [xMake| value.tuple.values := vs |]


-- Handle bijection differently since we need all the values anyway
evalChoice (CFunc _ FAttrs{fInjective=True, fSurjective=True,fTotal=_} from to) =
    findBijective from to

 --TODO If size is large gen all then select a few
evalChoice (CFunc sizeRange FAttrs{fInjective=True,fTotal=total} from to) = do
    size  <- evalRange sizeRange
    eFrom <- getFuncElements total size from
    eTo   <- findDistinct' (evalChoice to)   Set.empty size

    let vs = zipWith wrap eFrom eTo
    return [xMake| value.function.values := vs |]

    where
    wrap f t = [xMake| mapping := [f,t] |]

evalChoice (CFunc sizeRange FAttrs{fSurjective=True,fTotal=total} from to) = do
    size  <- evalRange sizeRange
    let eTo   =  allChoices to
        toLen =  genericLength eTo
    if size < toLen
    then error "evalChoice: surjective function invaild size"
    else do
        eFrom <- getFuncElements total size from

        let (vs,extraFrom) = genericSplitAt toLen eFrom

        let paired = zipWith wrap vs eTo
            extraFromLen = genericLength extraFrom

        extraTo <- pickN extraFromLen toLen eTo
        let extraPaired = zipWith wrap extraFrom extraTo

        return [xMake| value.function.values :=  (paired ++ extraPaired) |]

    where
    wrap f t = [xMake| mapping := [f,t] |]

evalChoice (CFunc sizeRange FAttrs{fSurjective=False,fInjective=False,fTotal=total} from to) = do
    size  <- evalRange sizeRange

    eFrom <- getFuncElements total size from
    eTo   <- mapM evalChoice (genericTake size $ repeat to)

    let vs = zipWith wrap eFrom eTo
    return [xMake| value.function.values := vs |]

    where
    wrap f t = [xMake| mapping := [f,t] |]


getFuncElements :: (RandomM m, MonadConjure m) =>Bool -> Integer -> Choice -> m [E]
getFuncElements getAll size dom  = 
    if getAll then
        return $ allChoices dom
    else 
        findDistinct' (evalChoice dom) Set.empty size

    

-- Pick n random elements from a list
pickN :: (MonadConjure m, RandomM m, Pretty a,Show a) => Integer -> Integer -> [a] -> m [a]
pickN 0 _    _ = return []
pickN n size ls = do
    index <- rangeRandomM (0, fromIntegral size-1)
    res <- pickN (n-1) size ls
    return $ ls `genericIndex` index : res


findBijective :: (MonadConjure m, RandomM m)
              => Choice -> Choice
              -> m E
findBijective from to = do
   let (allF, allT) = (choiceMap from, choiceMap to)
       fSize = M.size allF
       tSize = M.size allT
   if fSize /= tSize
   then _bugg "findBijective sizes not equal"
   else pairSets Set.empty tSize allF allT


   where
   choiceMap :: Choice -> Map E ()
   choiceMap choice =
       let allC   = allChoices choice
           tuples = map (flip  (,) ()) allC
       in M.fromDistinctAscList tuples

   pairSets :: (RandomM m) => Set [E] -> Int -> Map E () -> Map E () -> m E
   pairSets set 0 _ _  =
       let elems = Set.toAscList set
       in return $ [xMake| value.function.values := (map wrap elems) |]

     where
     wrap :: [E] -> E
     wrap array = [xMake| mapping := array |]

   pairSets set size fm tm  = do
     i1 <- rangeRandomM (0, size-1)
     i2 <- rangeRandomM (0, size-1)
     let (e1,_) = M.elemAt i1 fm
     let (e2,_) = M.elemAt i2 tm
     pairSets (Set.insert [e1,e2] set) (size - 1) (M.deleteAt i1 fm) (M.deleteAt i2 tm)


findDistinct'  :: (MonadConjure m, RandomM m, Ord a) => m a -> Set a -> Integer -> m [a] 
findDistinct' f set n =  return . Set.toAscList =<< findDistinct f set n  

-- Take a function which generates values and return n distinct values
findDistinct  :: (MonadConjure m, RandomM m, Ord a) => m a -> Set a -> Integer -> m (Set a)
findDistinct _ set 0    = return set
findDistinct f set size = do
    ele <- f
    let (size',set') = if Set.notMember ele set
        then (size - 1, Set.insert ele set)
        else (size,set)
    findDistinct f set' size'


evalRange :: (MonadConjure m, RandomM m) => Range -> m Integer
evalRange (RSingle i ) = return i
evalRange (RRange a b) = do
    let size  = b - a + 1
    index <- rangeRandomM (0, fromIntegral size-1)
    let picked = a + toInteger index
    mkLog "RangeData" $ sep  ["Range:"  <+> pretty (RRange a b)
                             ,"Index:"  <+> pretty index
                             ,"Picked:" <+> pretty picked
                             ]
    return picked


pickIth :: Integer -> [Range] -> Integer
pickIth _ [] = _bugg "pickIth no values"
pickIth 0 (RSingle i:_) = i
pickIth index (RRange a b:_ ) | index <= b - a = a + index

pickIth index (RSingle _:xs)    = pickIth (index - 1) xs
pickIth index (RRange a b:xs) = pickIth (index - (b - a) - 1 ) xs


allChoices :: Choice -> [E]
allChoices (CInt _ rs) = concatMap rangeToE rs
allChoices (CBool)     = [ [eMake| false |], [eMake| true |] ]

allChoices (CEnum _ (RSingle n) es)  = [es `genericIndex` n]
allChoices (CEnum _ (RRange a b) es) =  genericDrop a . genericTake (b+1) $ es

allChoices (CMatrix rs choice) =
    map (\p -> [xMake| value.matrix.values := p |] ) perms
    where size    = countRanges rs
          choices = allChoices choice
          perms   = permutationsN size choices

allChoices (CTuple cs) =
    map (\p -> [xMake| value.tuple.values := p |] ) cross
    where
    choices = map allChoices cs
    cross :: [[E]]
    cross   = cartesianProduct choices

allChoices (CSet size cs) =
    sort . map wrapper . filter (choiceFilterer size) . subsequences . allChoices $ cs
    where
    wrapper vs = [xMake| value.set.values := vs|]


allChoices (CRel size cs) =
    relChoice (choiceFilterer size) cross
    where
    cross = cartesianProduct . map allChoices $ cs

    relChoice :: ([[E]] -> Bool) -> [[E]] -> [E]
    relChoice  f es =
        map mapper elems
        where
        elems = filter f (subsequences es)
        wrap :: [E] -> E
        wrap vs   = [xMake| value.tuple.values := vs |]
        mapper vs = [xMake| value.relation.values := (map wrap vs) |]


choiceFilterer :: Range -> [b] -> Bool
choiceFilterer (RSingle n)  = (==) n . genericLength
choiceFilterer (RRange a b) = genericLength >>> (>=a) &&& (<=b) >>> uncurry (&&)

cartesianProduct :: [[a]] -> [[a]]
cartesianProduct = sequence

rangeToE :: Range -> [E]
rangeToE (RSingle i) = [[xMake| value.literal := [Prim (I i)] |]]
rangeToE (RRange a b) =
    map f [a..b]
    where f i = [xMake| value.literal := [Prim (I i)] |]

permutationsN :: Integer -> [a] -> [[a]]
permutationsN 0 _ = [[]]
permutationsN n array =  concatMap (\b -> map ((:) b ) res) array
    where res = permutationsN (n-1) array


_bug :: String -> [E] -> t
_bug  s = upBug  ("EvalChoice: " ++ s)
_bugg :: String -> t
_bugg s = _bug s []
