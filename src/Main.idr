||| Render a `.ipkg` file from JSON, using the compiler's own package-description
||| pretty-printer.
|||
||| Deserialization is derived by reflection (`Derive.FromJSON`); only two types
||| need hand-written instances, because their constructors are not usable from
||| outside the compiler:
|||
||| * `Core.FC.FC` — a source location, which has no JSON representation here
|||   and is always `EmptyFC`.
||| * `Core.Name.Namespace.ModuleIdent` — its constructor is private, so decoded
|||   module names go through the public `mkNamespace`.
|||
||| Both are written with qualified names: the reflection modules export types
||| called `FC` and `ModuleIdent` too, and the unqualified names are ambiguous.
module Main

import Core.FC
import Core.Name.Namespace
import Derive.FromJSON
import Derive.Prelude
import Idris.Package.Types
import JSON
import Libraries.Text.PrettyPrint.Prettyprinter
import System
import System.File

%language ElabReflection
%default total

--------------------------------------------------------------------------------
-- The only hand-written instances
--------------------------------------------------------------------------------

export
FromJSON Core.FC.FC where
  -- A source location has no JSON form here; it is only ever a placeholder.
  fromJSON _ = Right Core.FC.EmptyFC

export
FromJSON Core.Name.Namespace.ModuleIdent where
  -- `Parser v a` is `v -> Either JSONErr a`, so write it out directly.
  fromJSON str = case fromJSON {a = String} str of
    Left err => Left err
    Right s  => Right (nsAsModuleIdent (mkNamespace s))

--------------------------------------------------------------------------------
-- Everything else is derived
--------------------------------------------------------------------------------

%runElab derive "PkgVersion" [FromJSON]
%runElab derive "PkgVersionBounds" [FromJSON]
%runElab derive "Depends" [FromJSON]
%runElab derive "PkgDesc" [FromJSON]

--------------------------------------------------------------------------------
-- Entry point
--------------------------------------------------------------------------------

render : String -> Either String String
render s = do
  pkg <- the (Either String PkgDesc) (decodeEither s)
  pure $ show (the (Doc Void) (pretty pkg))

partial
readAll : File -> IO String
readAll h = do
  eof <- fEOF h
  if eof
    then pure ""
    else do
      line <- fGetLine h
      case line of
        Left _   => pure ""
        Right ln => do
          rest <- readAll h
          pure (ln ++ "\n" ++ rest)

partial
main : IO ()
main = do
  input <- readAll stdin
  case render input of
    Left err   => die $ "ipkg-render: " ++ err
    Right ipkg => putStr ipkg
