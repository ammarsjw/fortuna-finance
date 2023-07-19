import { Bytes, BigInt } from "@graphprotocol/graph-ts"

import {
  LedgerCreated as LedgerCreatedEvent,
  LedgerUpdated as LedgerUpdatedEvent,
  LedgerClaimed as LedgerClaimedEvent,
  Approval as ApprovalEvent,
  ExcludeFromFees as ExcludeFromFeesEvent,
  ExcludeMultipleAccountsFromFees as ExcludeMultipleAccountsFromFeesEvent,
  LiquidityWalletUpdated as LiquidityWalletUpdatedEvent,
  OwnershipTransferred as OwnershipTransferredEvent,
  SetAutomatedMarketMakerPair as SetAutomatedMarketMakerPairEvent,
  SwapAndLiquify as SwapAndLiquifyEvent,
  Transfer as TransferEvent,
  TreasuryWalletUpdated as TreasuryWalletUpdatedEvent,
  UpdatePancakeRouter as UpdatePancakeRouterEvent
} from "../generated/FortunasToken/FortunasToken"

import {
  LedgerCreated,
  LedgerUpdated,
  LedgerClaimed
} from "../generated/schema"

import { loadOrCreateTransaction } from "./utils/Transactions"

export function handleLedgerCreated(event: LedgerCreatedEvent): void {
  let transaction = loadOrCreateTransaction(event.transaction, event.block);
  let id = event.params.account.toHexString();
  let Ledger = LedgerCreated.load(id);
  if (!Ledger) {
    Ledger = new LedgerCreated(id);
    Ledger.account = event.params.account
  }
  Ledger.transaction = transaction.id
  Ledger.totalPassiveRewards = event.params.totalPassiveRewards
  Ledger.nextReward = event.params.nextReward
  Ledger.save()
}

export function handleLedgerUpdated(event: LedgerUpdatedEvent): void {
  let transaction = loadOrCreateTransaction(event.transaction, event.block);
  let id = event.params.account.toHexString();
  let Ledger = LedgerCreated.load(id);
  if (Ledger) {
    Ledger.transaction = transaction.id
    Ledger.totalPassiveRewards = event.params.totalPassiveRewards
    Ledger.nextReward = event.params.nextReward
    Ledger.save()
  }
}

export function handleLedgerClaimed(event: LedgerClaimedEvent): void {
  let transaction = loadOrCreateTransaction(event.transaction, event.block);
  let id = event.params.account.toHexString();
  let Ledger = LedgerCreated.load(id);
  if (Ledger) {
    Ledger.transaction = transaction.id
    Ledger.totalPassiveRewards = event.params.totalPassiveRewards
    Ledger.nextReward = event.params.nextReward
    Ledger.save()
  }
}