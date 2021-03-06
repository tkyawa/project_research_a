module Eval where

import Control.Exception
import Control.Monad
import Data.IORef
import Data.Typeable

import Data.Map.Strict
import Prelude hiding(lookup)

import Syntax
import Env 


-- evaluate ast

evalStatement :: Env -> Statement -> IO (Maybe TypeEnv)  

evalStatement env (Seq []) = return Nothing   

evalStatement env (Seq (h:t)) = do car <- evalStatement env h
                                   maybe (evalStatement env (Seq t)) (return . Just) car
 
--evalStatement env (Seq (h:t)) = do a <- evalStatement env h
    --                               evalStatement env (Seq t)


evalStatement env (If b x y) = do
    cond <- evalExpr env b
    case cond of
        TypeBool True -> evalStatement env x
        TypeBool False -> evalStatement env y
        _ -> error "If statement expected type 'Bool' as Expr"

evalStatement env (While e s) = do
    cond <- evalExpr env e
    case cond of 
        TypeBool True ->  evalStatement env (Seq[s,While e s]) 
        _ -> return Nothing


evalStatement env (Assign x n) = do 
    val <- evalExpr env n 
    defineVar env x val >> return Nothing


evalStatement env Skip = return Nothing  

evalStatement env (Return x) = Just <$> evalExpr env x

--- OpをSyntax上でまとめたら評価関数もまとめやすくなりそう

-- Expr 

evalExpr :: Env -> Expr -> IO TypeEnv  

---- Bool

evalExpr env (Bool True) = return (TypeBool True)
evalExpr env (Bool False) = return (TypeBool False) 


---- Integer 

evalExpr env (Integer x) = return (TypeInteger x)


---- Val 

evalExpr env (Var  x) = getVal env x

---- Func 

evalExpr env (Func arg body) = do closureEnv <- nullEnv
                                  return (Closure closureEnv arg body)

---- Apply

evalExpr env (Apply funcname param) = do 
        func <- evalExpr env funcname
        case func of 
                  Closure closureEnv arg body -> do
                      value <- evalExpr env param 
                      newenv <- defineVar closureEnv arg value
                      result <- evalStatement closureEnv body 
                      maybe (return Null) return result
                  _ -> error "Error in func"

------ BoolOp

evalExpr env (Greater x y) = do val1 <- evalExpr env x 
                                val2 <- evalExpr env y
                                return (evalOp2 val1 val2 "Greater") 

evalExpr env (Less x y) = do val1 <- evalExpr env x 
                             val2 <- evalExpr env y
                             return (evalOp2 val1 val2 "Less") 

evalExpr env (Equal x y) = do val1 <- evalExpr env x 
                              val2 <- evalExpr env y
                              return (evalOp2 val1 val2 "Equal") 

---- IntegerOp

evalExpr env (Add x y) = do val1 <- evalExpr env x 
                            val2 <- evalExpr env y
                            return (evalOp2 val1 val2 "Add") 

evalExpr env (Sub x y) = do val1 <- evalExpr env x 
                            val2 <- evalExpr env y
                            return (evalOp2 val1 val2 "Sub") 

evalExpr env (Mul x y) = do val1 <- evalExpr env x 
                            val2 <- evalExpr env y
                            return (evalOp2 val1 val2 "Mul") 


evalExpr env (Div x y) = do val1 <- evalExpr env x 
                            val2 <- evalExpr env y
                            return (evalOp2 val1 val2 "Div") 

evalExpr env (Pow x y) = do val1 <- evalExpr env x 
                            val2 <- evalExpr env y
                            return (evalOp2 val1 val2 "Pow") 
 
evalExpr env (Negative x) = do val <- evalExpr env x
                               return (evalOp1 val "Negative")

-- binary Op

evalOp2 :: TypeEnv -> TypeEnv -> String -> TypeEnv

---- BoolOp

evalOp2 (TypeInteger x) (TypeInteger y) "Greater" = TypeBool (x > y)
evalOp2 (TypeInteger x) (TypeInteger y) "Less" = TypeBool (x < y)
evalOp2 (TypeInteger x) (TypeInteger y) "Equal" = TypeBool (x == y)


---- IntegerOp

evalOp2 (TypeInteger x) (TypeInteger y) "Add" = TypeInteger (x + y)
evalOp2 (TypeInteger x) (TypeInteger y) "Sub" = TypeInteger (x - y)
evalOp2 (TypeInteger x) (TypeInteger y) "Mul" = TypeInteger (x * y)
evalOp2 (TypeInteger x) (TypeInteger y) "Div" = TypeInteger (div x  y)
evalOp2 (TypeInteger x) (TypeInteger y) "Pow" = TypeInteger (x ^ y)

evalOp2 _ _ _ = error "TypeError"


-- unary Op

evalOp1 :: TypeEnv -> String -> TypeEnv
evalOp1 (TypeInteger x) "Negative" = TypeInteger (-x)
evalOp1 _ _ = error "TypeError"
