module Main where

-- conjure tests
import Conjure.Prelude
import Conjure.Language.Type ( TypeCheckerMode(..) )
import qualified Conjure.Language.DomainSizeTest ( tests )
import qualified Conjure.RepresentationsTest ( tests )
import qualified Conjure.ModelAllSolveAll ( tests, TestTimeLimit(..) )
import qualified Conjure.TypeCheckAll ( tests )
import qualified Conjure.ParsePrint ( tests )
import qualified Conjure.Custom ( tests )

-- tasty
import Test.Tasty ( defaultMainWithIngredients, defaultIngredients, includingOptions, askOption, testGroup )
import Test.Tasty.Options ( OptionDescription(..) )

-- tasty-ant-xml
import Test.Tasty.Runners.AntXML ( antXMLRunner )


main :: IO ()
main = do
    let ?typeCheckerMode = StronglyTyped
    modelAllSolveAllTests <- Conjure.ModelAllSolveAll.tests
    typeCheckAllTests     <- Conjure.TypeCheckAll.tests
    parsePrintTests       <- Conjure.ParsePrint.tests
    customTests           <- Conjure.Custom.tests
    let ingredients = antXMLRunner
                    : includingOptions [Option (Proxy :: Proxy Conjure.ModelAllSolveAll.TestTimeLimit)]
                    : defaultIngredients
    defaultMainWithIngredients ingredients $ askOption $ \ testTimeLimit ->
        testGroup "conjure"
            [ Conjure.Language.DomainSizeTest.tests
            , Conjure.RepresentationsTest.tests
            , parsePrintTests
            , modelAllSolveAllTests testTimeLimit
            , typeCheckAllTests
            , customTests testTimeLimit
            ]
