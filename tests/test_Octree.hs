{-# LANGUAGE TemplateHaskell, ScopedTypeVariables #-}
module Main(main) where

import Data.Octree.Internal
import Data.Octree.Instances()
import Data.Octree() -- test that interface module is not broken
import Prelude hiding(lookup)
import Data.List(sort, sortBy)

import Test.QuickCheck.All(quickCheckAll)
import Test.QuickCheck.Arbitrary

import Data.Vector.Class
import Control.Arrow(second)

-- | For testing purposes
instance Ord Vector3 where
  a `compare` b = pointwiseOrd $ zipWith compare (vunpack a) (vunpack b)

pointwiseOrd []      = EQ
pointwiseOrd (LT:cs) = LT
pointwiseOrd (GT:cs) = GT
pointwiseOrd (EQ:cs) = pointwiseOrd cs

instance Arbitrary Vector3 where
  arbitrary = do x <- arbitrary
                 y <- arbitrary
                 z <- arbitrary
                 return $ Vector3 x y z

-- | These are tests for internal helper functions:

-- for easier testing
origin :: Vector3
origin = 0

prop_depth a = (depth oct <= ((+1)        . ceiling $ expectedDepth)) &&
               (depth oct >= ((\a -> a-1) . floor   $ expectedDepth))
  where
    expectedDepth = (logBase 8 :: Double -> Double) . fromIntegral . length $ a
    oct :: Octree Int = fromList a

prop_cmp1 a b = cmp a b == joinStep (dx >= 0, dy >= 0, dz >= 0)
  where Vector3 dx dy dz = a - b

prop_cmp2 a = cmp a origin == joinStep (dx >= 0, dy >= 0, dz >= 0)
  where Vector3 dx dy dz = a

prop_stepDescription a b = splitStep (cmp a b) == (v3x a >= v3x b, v3y a >= v3y b, v3z a >= v3z b)

prop_octantDistanceNoGreaterThanInterpointDistance0 ptA ptB = triangleInequality 
  where triangleInequality = octantDistance' aptA (cmp ptB origin) <= dist aptA ptB
        aptA               = abs ptA

prop_octantDistanceNoGreaterThanInterpointDistance ptA ptB vp = triangleInequality
  where triangleInequality = octantDistance (ptA - vp) (cmp ptB vp) <= dist ptA ptB
        sameOctant         = cmp ptA vp == cmp ptB vp

prop_octantDistanceNoGreaterThanInterpointDistanceZero ptA ptB = triangleInequality
  where triangleInequality = octantDistance ptA (cmp ptB origin) <= dist ptA ptB
        sameOctant         = cmp ptA origin == cmp ptB origin

prop_octantDistanceNoGreaterThanInterpointDistanceZero0 ptA ptB = triangleInequality
  where triangleInequality = octantDistance aptA (cmp ptB origin) <= dist aptA ptB
        sameOctant         = cmp aptA origin                      == cmp ptB origin
        aptA               = abs ptA

prop_octantDistanceNoGreaterThanCentroidDistance pt vp = all testFun allOctants
  where testFun odir = octantDistance (pt - vp) odir <= dist pt vp

prop_splitByPrime splitPt pt = (unLeaf . octreeStep ot . cmp pt $ splitPt) == [arg]
  where ot   = splitBy' Leaf splitPt [arg] 
        arg  = (pt, dist pt splitPt)


prop_pickClosest :: (Eq a) => [(Vector3, a)] -> Vector3 -> Bool
prop_pickClosest        l pt = pickClosest pt l == naiveNearest pt l

-- | These are tests for exposed functions:

prop_lookup l = all isIn l
  where ot = fromList l
        isIn x = lookup ot (fst x) == Just x

prop_fromToList         l = sort l == (sort . toList . fromList $ l)
prop_insertionPreserved l = sort l == (sort . toList . foldr insert (Leaf []) $ l)
prop_nearest            l pt = nearest (fromList l) pt == naiveNearest pt l
prop_naiveWithinRange   r l pt = naiveWithinRange r pt l == (sort . map fst . (\o -> withinRange o r pt) . fromList . tuplify pt $ l)

tuplify pt = map (\a -> (a, dist pt a))

compareDistance pt a b = compare (dist pt (fst a)) (dist pt (fst b))

naiveNearest pt l = if byDist == [] then Nothing else Just . head $ byDist
  where byDist = sortBy (compareDistance pt) l

naiveWithinRange r pt l = sort . filter (\p -> dist pt p <= r) $ l

-- unfortunately there is no Arbitrary for (a -> b)
-- since generic properties are quite common, I wonder how to force Quickcheck to default something reasonable?
prop_fmap1 l = genericProperty_fmap (+1) l
prop_fmap2 l = genericProperty_fmap (*2) l
prop_fmap3 l = genericProperty_fmap show l

genericProperty_fmap f l = (sort . map (Control.Arrow.second f) $ l) == (sort . toList . fmap f . fromList $ l)

prop_depth_empty = depth (Leaf []) == 0

prop_depth_upper_bound l = depth ot <= max 0 (ceiling . logBase 2 . realToFrac $ size) -- worst splitting ratio possible when we take midpoint (and inputs are colinear)
  where ot   = fromList l
        size = length l

prop_size l = size (fromList l) == length l

main = $quickCheckAll
