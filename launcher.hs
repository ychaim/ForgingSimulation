{-# LANGUAGE ScopedTypeVariables #-}
module Main where

import Blockchain.Simulation
import Blockchain.Structures
import qualified Data.Map as Map
import System.Directory
import Data.ConfigFile as ConfigFile
import Data.Either.Utils


outChain :: BlockChain -> String
outChain chain = concat [chainInfo, diffInfo]
    where
        diffInfo = concat ["Cumulative difficulty: ", show $ cumulativeDifficulty chain]
        chainInfo = foldl(\s b -> concat [s, show $ blockTimestamp b, " -> ",show $ generator b, "--",
                                            show $ blockId b ," -- ", show $ length $ transactions b, "\n "]) "" chain

outChainNode :: Node -> String
outChainNode node = outChain $ nodeChain $ localView node


outTxs :: Node -> String
outTxs node = foldl(\s t -> concat [s, show t]) "" txs
    where
        chain = nodeChain $ localView node
        txs = concat $ map transactions $ tail chain

outConnection :: Network -> String
outConnection network = concat ps
    where
        cons = connections network
        ks = Map.keys cons
        ps = map (\k -> concat [show $ nodeId $ k, " -> ", show $ Map.findWithDefault [] k cons, "\n "]) ks

commonChainLength :: Node -> Node -> Int
commonChainLength n1 n2 = length $ commonChain (nodeChain $ localView n1)(nodeChain $ localView n2) []

commonChainsNode :: Node -> [Node] ->  String
commonChainsNode n ns = show (let others = filter (/=n) ns in map (commonChainLength n) others)

commonChains :: [Node] -> String
commonChains ns = show $ map (\n -> concat[show $ nodeId n," : ",show $ selfBalance n ,"<->", commonChainsNode n ns]) ns


main = do
    putStrLn "Starting cryptocurrency simulation..."

    val <- ConfigFile.readfile ConfigFile.emptyCP "params.conf"
    let cp = forceEither val

    let outdir = forceEither $ ConfigFile.get cp "DEFAULT" "outdir"

    let initSimData = SimulationData{
        timestamp = 0,
        simulationId = forceEither $ ConfigFile.get cp "DEFAULT" "simulation-id",
        maxConnectionsPerNode = forceEither $ ConfigFile.get cp "DEFAULT" "max-connections-per-node",
        addNodeAvgGap = forceEither $ ConfigFile.get cp "DEFAULT" "add-node-avg-gap",
        deadline = forceEither $ ConfigFile.get cp "DEFAULT" "duration"}

    createDirectoryIfMissing True outdir

    let network = snd $ goThrouhTimeline (initSimData, genesisState)
    let ns = nodes network

    writeFile (concat [outdir, "/network"]) (show network)
    writeFile (concat [outdir, "/cons"]) (outConnection network)
    mapM_ (\i -> writeFile (concat [outdir, "/node", show i]) (show (ns !! i))) [0..(length ns - 1)]
    mapM_ (\i -> writeFile (concat [outdir, "/chain", show i]) (outChainNode $ ns !! i)) [0..(length ns - 1)]
    mapM_ (\i -> writeFile (concat [outdir, "/txs", show i]) (outTxs $ ns !! i)) [0..(length ns - 1)]
    mapM_ (\i -> writeFile (concat [outdir, "/common", show i]) (outChain $ commonChain (nodeChain $ localView $ ns !! i) (nodeChain $ localView $ ns !! (i+1)) [] )) [0..(length ns - 2)]

    putStrLn "Final balances(from self point of view):"
    putStrLn $ show $ map selfBalance ns
    putStrLn "\n"
    putStrLn "Node Id : Self balance <-> Common chain lengths with other nodes: "
    let cc = commonChains ns
    writeFile (concat [outdir, "/commons"]) cc
    putStrLn $ cc
    putStrLn "\n Cryptocurrency simulation has been finished"