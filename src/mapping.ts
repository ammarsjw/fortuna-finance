import { Bytes, BigInt } from "@graphprotocol/graph-ts"

import {
  BattleStarted as BattleStartedEvent,
  BattleUpdated as BattleUpdatedEvent,
  BattleEnded as BattleEndedEvent,
  HeroPurchased as HeroPurchasedEvent,
  HeroDeployed as HeroDeployedEvent,
  HeroReturned as HeroReturnedEvent,
  HeroLost as HeroLostEvent,
  CavalryPurchased as CavalryPurchasedEvent,
  CavalryDeployed as CavalryDeployedEvent,
  CavalryReturned as CavalryReturnedEvent,
  CavalryLost as CavalryLostEvent
} from "../generated/Battling/Battling"

import {
  BattleStarted,
  BattleUpdated,
  BattleEnded,
  HeroPurchased,
  HeroDeployed,
  HeroReturned,
  HeroLost,
  CavalryPurchased,
  CavalryDeployed,
  CavalryReturned,
  CavalryLost
} from "../generated/schema"

import { loadOrCreateTransaction } from "./utils/Transactions"

export function handleBattleStarted(event: BattleStartedEvent): void {
  let transaction = loadOrCreateTransaction(event.transaction, event.block);
  let id = event.params.user.toHexString().concat(event.params.battleType.toString());
  let battle = BattleStarted.load(id);
  if (!battle) {
    battle = new BattleStarted(id);
    battle.transaction = transaction.id
    battle.user = event.params.user
    battle.battleType = event.params.battleType
  }
  battle.battleStatus = event.params.battleStatus
  battle.tokensStaked = event.params.tokensStaked
  battle.battleStartTime = event.params.battleStartTime
  battle.battleDurationInDays = event.params.battleDurationInDays
  battle.rewards = event.params.rewards
  battle.rations = event.params.rations
  battle.save()
}

export function handleBattleUpdated(event: BattleUpdatedEvent): void {
  let transaction = loadOrCreateTransaction(event.transaction, event.block);
  let id = event.params.user.toHexString().concat(event.params.battleType.toString());
  let battle = BattleStarted.load(id);
  if (battle) {
    battle.transaction = transaction.id
    battle.battleStatus = event.params.battleStatus
    battle.tokensStaked = event.params.tokensStaked
    battle.battleStartTime = event.params.battleStartTime
    battle.battleDurationInDays = event.params.battleDurationInDays
    battle.rewards = event.params.rewards
    battle.rations = event.params.rations
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
    battle.tokensStaked = event.params.tokensStaked
    battle.battleStartTime = event.params.battleStartTime
    battle.battleDurationInDays = event.params.battleDurationInDays
    battle.rewards = event.params.rewards
    battle.rations = event.params.rations
    battle.save()
  }
}

export function handleHeroPurchased(event: HeroPurchasedEvent): void {
  let transaction = loadOrCreateTransaction(event.transaction, event.block);
  let id = event.params.user.toHexString().concat(event.params.hero.toString());
  let hero = HeroPurchased.load(id);
  if (!hero) {
    hero = new HeroPurchased(id);
    hero.transaction = transaction.id
    hero.user = event.params.user
    hero.hero = event.params.hero
  }
  hero.battleType = event.params.battleType
  hero.heroStatus = event.params.heroStatus
}

export function handleHeroDeployed(event: HeroDeployedEvent): void {
  let transaction = loadOrCreateTransaction(event.transaction, event.block);
  let id = event.params.user.toHexString().concat(event.params.hero.toString());
  let hero = HeroPurchased.load(id);
  if (hero) {
    hero.transaction = transaction.id
    hero.battleType = event.params.battleType
    hero.heroStatus = event.params.heroStatus
  }
}

export function handleHeroReturned(event: HeroReturnedEvent): void {
  let transaction = loadOrCreateTransaction(event.transaction, event.block);
  let id = event.params.user.toHexString().concat(event.params.hero.toString());
  let hero = HeroPurchased.load(id);
  if (hero) {
    hero.transaction = transaction.id
    hero.battleType = event.params.battleType
    hero.heroStatus = event.params.heroStatus
  }
}

export function handleHeroLost(event: HeroLostEvent): void {
  let transaction = loadOrCreateTransaction(event.transaction, event.block);
  let id = event.params.user.toHexString().concat(event.params.hero.toString());
  let hero = HeroPurchased.load(id);
  if (hero) {
    hero.transaction = transaction.id
    hero.battleType = event.params.battleType
    hero.heroStatus = event.params.heroStatus
  }
}

export function handleCavalryPurchased(event: CavalryPurchasedEvent): void {
  let transaction = loadOrCreateTransaction(event.transaction, event.block);
  let id = event.params.user.toHexString().concat(event.params.cavalry.toString());
  let cavalry = CavalryPurchased.load(id);
  if (!cavalry) {
    cavalry = new CavalryPurchased(id);
    cavalry.transaction = transaction.id
    cavalry.user = event.params.user
    cavalry.cavalry = event.params.cavalry
  }
  cavalry.battleType = event.params.battleType
  cavalry.cavalryStatus = event.params.cavalryStatus
}

export function handleCavalryDeployed(event: CavalryDeployedEvent): void {
  let transaction = loadOrCreateTransaction(event.transaction, event.block);
  let id = event.params.user.toHexString().concat(event.params.cavalry.toString());
  let cavalry = CavalryPurchased.load(id);
  if (cavalry) {
    cavalry.transaction = transaction.id
    cavalry.battleType = event.params.battleType
    cavalry.cavalryStatus = event.params.cavalryStatus
  }
}

export function handleCavalryReturned(event: CavalryReturnedEvent): void {
  let transaction = loadOrCreateTransaction(event.transaction, event.block);
  let id = event.params.user.toHexString().concat(event.params.cavalry.toString());
  let cavalry = CavalryPurchased.load(id);
  if (cavalry) {
    cavalry.transaction = transaction.id
    cavalry.battleType = event.params.battleType
    cavalry.cavalryStatus = event.params.cavalryStatus
  }
}

export function handleCavalryLost(event: CavalryLostEvent): void {
  let transaction = loadOrCreateTransaction(event.transaction, event.block);
  let id = event.params.user.toHexString().concat(event.params.cavalry.toString());
  let cavalry = CavalryPurchased.load(id);
  if (cavalry) {
    cavalry.transaction = transaction.id
    cavalry.battleType = event.params.battleType
    cavalry.cavalryStatus = event.params.cavalryStatus
  }
}