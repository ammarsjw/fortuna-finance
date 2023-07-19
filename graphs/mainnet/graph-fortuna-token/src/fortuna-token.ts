import { Bytes, BigInt } from "@graphprotocol/graph-ts"

import {
  Approval as ApprovalEvent,
  Transfer as TransferEvent,
  CreatedLedger as CreatedLedgerEvent,
  ClaimedLedger as ClaimedLedgerEvent,
  ExcludedFromFees as ExcludedFromFeesEvent,
  ExcludedMultipleAccountsFromFees as ExcludedMultipleAccountsFromFeesEvent,
  ExcludedFromPassiveRewards as ExcludedFromPassiveRewardsEvent,
  ExcludedMultipleAccountsFromPassiveRewards as ExcludedMultipleAccountsFromPassiveRewardsEvent,
  SetAutomatedMarketMakerPair as SetAutomatedMarketMakerPairEvent,
  UpdatedBuyingFees as UpdatedBuyingFeesEvent,
  UpdatedSellingFees as UpdatedSellingFeesEvent,
  UpdatedLiquidityWallet as UpdatedLiquidityWalletEvent,
  UpdatedTreasuryWallet as UpdatedTreasuryWalletEvent,
  UpdatedRewardWallet as UpdatedRewardWalletEvent,
  UpdatedPancakeRouter as UpdatedPancakeRouterEvent,
  OwnershipTransferred as OwnershipTransferredEvent
} from "../generated/FortunaToken/FortunaToken"

import {
  Approval,
  Transfer,
  CreatedLedger,
  ClaimedLedger,
  ExcludedFromFees,
  ExcludedMultipleAccountsFromFees,
  ExcludedFromPassiveRewards,
  ExcludedMultipleAccountsFromPassiveRewards,
  SetAutomatedMarketMakerPair,
  UpdatedBuyingFees,
  UpdatedSellingFees,
  UpdatedLiquidityWallet,
  UpdatedTreasuryWallet,
  UpdatedRewardWallet,
  UpdatedPancakeRouter,
  OwnershipTransferred
} from "../generated/schema"

import { loadOrCreateTransaction } from "./utils/Transactions"

export function handleApproval(event: ApprovalEvent): void {
  let transaction = loadOrCreateTransaction(event.transaction, event.block)
  let entity = new Approval(transaction.id)
  entity.transaction = transaction.id
  entity.owner = event.params.owner
  entity.spender = event.params.spender
  entity.value = event.params.value
  entity.save()
}

export function handleTransfer(event: TransferEvent): void {
  let transaction = loadOrCreateTransaction(event.transaction, event.block)
  let id = transaction.id.toString().concat("-").concat(event.params.from.toHexString()).concat("-").concat(event.params.to.toHexString()).concat("-").concat(event.params.value.toString())
  let entity = new Transfer(id)
  entity.transaction = transaction.id
  entity.from = event.params.from
  entity.to = event.params.to
  entity.value = event.params.value
  entity.save()
}

export function handleCreatedLedger(event: CreatedLedgerEvent): void {
  let transaction = loadOrCreateTransaction(event.transaction, event.block)
  let id = transaction.id.toString().concat("-").concat(event.params.account.toHexString())
  let entity = new CreatedLedger(id)
  entity.transaction = transaction.id
  entity.account = event.params.account
  entity.save()
}

export function handleClaimedLedger(event: ClaimedLedgerEvent): void {
  let transaction = loadOrCreateTransaction(event.transaction, event.block)
  let id = transaction.id.toString().concat("-").concat(event.params.account.toHexString()).concat("-").concat(event.params.totalPassiveRewards.toString());
  let entity = new ClaimedLedger(id)
  entity.transaction = transaction.id
  entity.account = event.params.account
  entity.totalPassiveRewards = event.params.totalPassiveRewards
  entity.save()
}

export function handleExcludedFromFees(event: ExcludedFromFeesEvent): void {
  let transaction = loadOrCreateTransaction(event.transaction, event.block)
  let entity = new ExcludedFromFees(transaction.id)
  entity.transaction = transaction.id
  entity.account = event.params.account
  entity.isExcluded = event.params.isExcluded
  entity.save()
}

export function handleExcludedMultipleAccountsFromFees(event: ExcludedMultipleAccountsFromFeesEvent): void {
  let transaction = loadOrCreateTransaction(event.transaction, event.block)
  let entity = new ExcludedMultipleAccountsFromFees(transaction.id)
  entity.transaction = transaction.id
  entity.isExcluded = event.params.isExcluded
  entity.save()
}

export function handleExcludedFromPassiveRewards(event: ExcludedFromPassiveRewardsEvent): void {
  let transaction = loadOrCreateTransaction(event.transaction, event.block)
  let entity = new ExcludedFromPassiveRewards(transaction.id)
  entity.transaction = transaction.id
  entity.account = event.params.account
  entity.isExcluded = event.params.isExcluded
  entity.save()
}

export function handleExcludedMultipleAccountsFromPassiveRewards(event: ExcludedMultipleAccountsFromPassiveRewardsEvent): void {
  let transaction = loadOrCreateTransaction(event.transaction, event.block)
  let entity = new ExcludedMultipleAccountsFromPassiveRewards(transaction.id)
  entity.transaction = transaction.id
  entity.isExcluded = event.params.isExcluded
  entity.save()
}

export function handleSetAutomatedMarketMakerPair(event: SetAutomatedMarketMakerPairEvent): void {
  let transaction = loadOrCreateTransaction(event.transaction, event.block)
  let entity = new SetAutomatedMarketMakerPair(transaction.id)
  entity.transaction = transaction.id
  entity.pair = event.params.pair
  entity.value = event.params.value
  entity.save()
}

export function handleUpdatedBuyingFees(event: UpdatedBuyingFeesEvent): void {
  let transaction = loadOrCreateTransaction(event.transaction, event.block)
  let entity = new UpdatedBuyingFees(transaction.id)
  entity.transaction = transaction.id
  entity.newLiquidityBuyingFee = event.params.newLiquidityBuyingFee
  entity.newTreasuryBuyingFee = event.params.newTreasuryBuyingFee
  entity.newBurnBuyingFee = event.params.newBurnBuyingFee
  entity.save()
}

export function handleUpdatedSellingFees(event: UpdatedSellingFeesEvent): void {
  let transaction = loadOrCreateTransaction(event.transaction, event.block)
  let entity = new UpdatedSellingFees(transaction.id)
  entity.transaction = transaction.id
  entity.newLiquiditySellingFee = event.params.newLiquiditySellingFee
  entity.newTreasurySellingFee = event.params.newTreasurySellingFee
  entity.newBurnSellingFee = event.params.newBurnSellingFee
  entity.save()
}

export function handleUpdatedLiquidityWallet(event: UpdatedLiquidityWalletEvent): void {
  let transaction = loadOrCreateTransaction(event.transaction, event.block)
  let entity = new UpdatedLiquidityWallet(transaction.id)
  entity.transaction = transaction.id
  entity.newLiquidityWallet = event.params.newLiquidityWallet
  entity.oldLiquidityWallet = event.params.oldLiquidityWallet
  entity.save()
}

export function handleUpdatedTreasuryWallet(event: UpdatedTreasuryWalletEvent): void {
  let transaction = loadOrCreateTransaction(event.transaction, event.block)
  let entity = new UpdatedTreasuryWallet(transaction.id)
  entity.transaction = transaction.id
  entity.newTreasuryWallet = event.params.newTreasuryWallet
  entity.oldTreasuryWallet = event.params.oldTreasuryWallet
  entity.save()
}

export function handleUpdatedRewardWallet(event: UpdatedRewardWalletEvent): void {
  let transaction = loadOrCreateTransaction(event.transaction, event.block)
  let entity = new UpdatedRewardWallet(transaction.id)
  entity.transaction = transaction.id
  entity.newRewardWallet = event.params.newRewardWallet
  entity.oldRewardWallet = event.params.oldRewardWallet
  entity.save()
}

export function handleUpdatedPancakeRouter(event: UpdatedPancakeRouterEvent): void {
  let transaction = loadOrCreateTransaction(event.transaction, event.block)
  let entity = new UpdatedPancakeRouter(transaction.id)
  entity.transaction = transaction.id
  entity.newAddress = event.params.newAddress
  entity.oldAddress = event.params.oldAddress
  entity.save()
}

export function handleOwnershipTransferred(event: OwnershipTransferredEvent): void {
  let transaction = loadOrCreateTransaction(event.transaction, event.block)
  let entity = new OwnershipTransferred(transaction.id)
  entity.transaction = transaction.id
  entity.previousOwner = event.params.previousOwner
  entity.newOwner = event.params.newOwner
  entity.save()
}