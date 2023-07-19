import { Bytes, BigInt } from "@graphprotocol/graph-ts"

import {
  BattleStarted as BattleStartedEvent,
  BattleUpdated as BattleUpdatedEvent,
  BattleEnded as BattleEndedEvent,
  AssetPurchased as AssetPurchasedEvent,
  AssetDeployed as AssetDeployedEvent,
  AssetReturned as AssetReturnedEvent,
  AssetLost as AssetLostEvent
} from "../generated/Battling/Battling"

import {
  BattleStarted,
  BattleUpdated,
  BattleEnded,
  AssetPurchased,
  AssetDeployed,
  AssetReturned,
  AssetLost
} from "../generated/schema"

import { loadOrCreateTransaction } from "./utils/Transactions"

export function handleBattleStarted(event: BattleStartedEvent): void {
  let transaction = loadOrCreateTransaction(event.transaction, event.block);
  let id = event.params.user.toHexString().concat(event.params.battleType.toString());
  let battle = BattleStarted.load(id);
  if (!battle) {
    battle = new BattleStarted(id);
    battle.user = event.params.user
    battle.battleType = event.params.battleType
  }
  battle.transaction = transaction.id
  battle.battleStatus = event.params.battleStatus
  battle.initialTokensStaked = event.params.initialTokensStaked
  battle.additionalTokens = event.params.additionalTokens
  battle.rewards = event.params.rewards
  battle.rations = event.params.rations
  battle.passiveRewards = event.params.passiveRewards
  battle.battleStartTime = event.params.battleStartTime
  battle.battleDurationInDays = event.params.battleDurationInDays
  battle.hero = event.params.hero
  battle.cavalry = event.params.cavalry
  battle.save()
}

export function handleBattleUpdated(event: BattleUpdatedEvent): void {
  let transaction = loadOrCreateTransaction(event.transaction, event.block);
  let id = event.params.user.toHexString().concat(event.params.battleType.toString());
  let battle = BattleStarted.load(id);
  if (battle) {
    battle.transaction = transaction.id
    battle.battleStatus = event.params.battleStatus
    battle.initialTokensStaked = event.params.initialTokensStaked
    battle.additionalTokens = event.params.additionalTokens
    battle.rewards = event.params.rewards
    battle.rations = event.params.rations
    battle.passiveRewards = event.params.passiveRewards
    battle.battleStartTime = event.params.battleStartTime
    battle.battleDurationInDays = event.params.battleDurationInDays
    battle.hero = event.params.hero
    battle.cavalry = event.params.cavalry
    battle.save()
  }
}

export function handleBattleEnded(event: BattleEndedEvent): void {
  let transaction = loadOrCreateTransaction(event.transaction, event.block);
  let id = event.params.user.toHexString().concat(event.params.battleType.toString());
  let battle = BattleStarted.load(id);
  if (battle) {
    battle.transaction = transaction.id
    battle.battleStatus = event.params.battleStatus
    battle.initialTokensStaked = event.params.initialTokensStaked
    battle.additionalTokens = event.params.additionalTokens
    battle.rewards = event.params.rewards
    battle.rations = event.params.rations
    battle.passiveRewards = event.params.passiveRewards
    battle.battleStartTime = event.params.battleStartTime
    battle.battleDurationInDays = event.params.battleDurationInDays
    battle.hero = event.params.hero
    battle.cavalry = event.params.cavalry
    battle.save()
  }
}

export function handleAssetPurchased(event: AssetPurchasedEvent): void {
  let transaction = loadOrCreateTransaction(event.transaction, event.block);
  let id = event.params.user.toHexString().concat(event.params.asset.toString());
  let asset = AssetPurchased.load(id);
  if (!asset) {
    asset = new AssetPurchased(id);
    asset.user = event.params.user
    asset.asset = event.params.asset
  }
  asset.transaction = transaction.id
  asset.amount = event.params.amount
  asset.save()
}

export function handleAssetDeployed(event: AssetDeployedEvent): void {
  let transaction = loadOrCreateTransaction(event.transaction, event.block);
  let id = event.params.user.toHexString().concat(event.params.asset.toString());
  let asset = AssetPurchased.load(id);
  if (asset) {
    asset.transaction = transaction.id
    asset.amount = event.params.amount
    asset.save()
  }
}

export function handleAssetReturned(event: AssetReturnedEvent): void {
  let transaction = loadOrCreateTransaction(event.transaction, event.block);
  let id = event.params.user.toHexString().concat(event.params.asset.toString());
  let asset = AssetPurchased.load(id);
  if (asset) {
    asset.transaction = transaction.id
    asset.amount = event.params.amount
    asset.save()
  }
}

export function handleAssetLost(event: AssetLostEvent): void {
  let transaction = loadOrCreateTransaction(event.transaction, event.block);
  let id = event.params.user.toHexString().concat(event.params.asset.toString());
  let asset = AssetPurchased.load(id);
  if (asset) {
    asset.transaction = transaction.id
    asset.amount = event.params.amount
    asset.save()
  }
}