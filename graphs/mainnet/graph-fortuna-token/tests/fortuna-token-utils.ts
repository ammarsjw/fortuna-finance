import { newMockEvent } from "matchstick-as"
import { ethereum, Address, BigInt } from "@graphprotocol/graph-ts"
import {
  Approval,
  ClaimedLedger,
  CreatedLedger,
  ExcludedFromFees,
  ExcludedFromPassiveRewards,
  ExcludedMultipleAccountsFromFees,
  ExcludedMultipleAccountsFromPassiveRewards,
  OwnershipTransferred,
  SetAutomatedMarketMakerPair,
  Transfer,
  UpdatedBuyingFees,
  UpdatedLiquidityWallet,
  UpdatedPancakeRouter,
  UpdatedRewardWallet,
  UpdatedSellingFees,
  UpdatedTreasuryWallet
} from "../generated/FortunaToken/FortunaToken"

export function createApprovalEvent(
  owner: Address,
  spender: Address,
  value: BigInt
): Approval {
  let approvalEvent = changetype<Approval>(newMockEvent())

  approvalEvent.parameters = new Array()

  approvalEvent.parameters.push(
    new ethereum.EventParam("owner", ethereum.Value.fromAddress(owner))
  )
  approvalEvent.parameters.push(
    new ethereum.EventParam("spender", ethereum.Value.fromAddress(spender))
  )
  approvalEvent.parameters.push(
    new ethereum.EventParam("value", ethereum.Value.fromUnsignedBigInt(value))
  )

  return approvalEvent
}

export function createClaimedLedgerEvent(
  account: Address,
  totalPassiveRewards: BigInt
): ClaimedLedger {
  let claimedLedgerEvent = changetype<ClaimedLedger>(newMockEvent())

  claimedLedgerEvent.parameters = new Array()

  claimedLedgerEvent.parameters.push(
    new ethereum.EventParam("account", ethereum.Value.fromAddress(account))
  )
  claimedLedgerEvent.parameters.push(
    new ethereum.EventParam(
      "totalPassiveRewards",
      ethereum.Value.fromUnsignedBigInt(totalPassiveRewards)
    )
  )

  return claimedLedgerEvent
}

export function createCreatedLedgerEvent(account: Address): CreatedLedger {
  let createdLedgerEvent = changetype<CreatedLedger>(newMockEvent())

  createdLedgerEvent.parameters = new Array()

  createdLedgerEvent.parameters.push(
    new ethereum.EventParam("account", ethereum.Value.fromAddress(account))
  )

  return createdLedgerEvent
}

export function createExcludedFromFeesEvent(
  account: Address,
  isExcluded: boolean
): ExcludedFromFees {
  let excludedFromFeesEvent = changetype<ExcludedFromFees>(newMockEvent())

  excludedFromFeesEvent.parameters = new Array()

  excludedFromFeesEvent.parameters.push(
    new ethereum.EventParam("account", ethereum.Value.fromAddress(account))
  )
  excludedFromFeesEvent.parameters.push(
    new ethereum.EventParam(
      "isExcluded",
      ethereum.Value.fromBoolean(isExcluded)
    )
  )

  return excludedFromFeesEvent
}

export function createExcludedFromPassiveRewardsEvent(
  account: Address,
  isExcluded: boolean
): ExcludedFromPassiveRewards {
  let excludedFromPassiveRewardsEvent = changetype<ExcludedFromPassiveRewards>(
    newMockEvent()
  )

  excludedFromPassiveRewardsEvent.parameters = new Array()

  excludedFromPassiveRewardsEvent.parameters.push(
    new ethereum.EventParam("account", ethereum.Value.fromAddress(account))
  )
  excludedFromPassiveRewardsEvent.parameters.push(
    new ethereum.EventParam(
      "isExcluded",
      ethereum.Value.fromBoolean(isExcluded)
    )
  )

  return excludedFromPassiveRewardsEvent
}

export function createExcludedMultipleAccountsFromFeesEvent(
  accounts: Array<Address>,
  isExcluded: boolean
): ExcludedMultipleAccountsFromFees {
  let excludedMultipleAccountsFromFeesEvent = changetype<
    ExcludedMultipleAccountsFromFees
  >(newMockEvent())

  excludedMultipleAccountsFromFeesEvent.parameters = new Array()

  excludedMultipleAccountsFromFeesEvent.parameters.push(
    new ethereum.EventParam(
      "accounts",
      ethereum.Value.fromAddressArray(accounts)
    )
  )
  excludedMultipleAccountsFromFeesEvent.parameters.push(
    new ethereum.EventParam(
      "isExcluded",
      ethereum.Value.fromBoolean(isExcluded)
    )
  )

  return excludedMultipleAccountsFromFeesEvent
}

export function createExcludedMultipleAccountsFromPassiveRewardsEvent(
  accounts: Array<Address>,
  isExcluded: boolean
): ExcludedMultipleAccountsFromPassiveRewards {
  let excludedMultipleAccountsFromPassiveRewardsEvent = changetype<
    ExcludedMultipleAccountsFromPassiveRewards
  >(newMockEvent())

  excludedMultipleAccountsFromPassiveRewardsEvent.parameters = new Array()

  excludedMultipleAccountsFromPassiveRewardsEvent.parameters.push(
    new ethereum.EventParam(
      "accounts",
      ethereum.Value.fromAddressArray(accounts)
    )
  )
  excludedMultipleAccountsFromPassiveRewardsEvent.parameters.push(
    new ethereum.EventParam(
      "isExcluded",
      ethereum.Value.fromBoolean(isExcluded)
    )
  )

  return excludedMultipleAccountsFromPassiveRewardsEvent
}

export function createOwnershipTransferredEvent(
  previousOwner: Address,
  newOwner: Address
): OwnershipTransferred {
  let ownershipTransferredEvent = changetype<OwnershipTransferred>(
    newMockEvent()
  )

  ownershipTransferredEvent.parameters = new Array()

  ownershipTransferredEvent.parameters.push(
    new ethereum.EventParam(
      "previousOwner",
      ethereum.Value.fromAddress(previousOwner)
    )
  )
  ownershipTransferredEvent.parameters.push(
    new ethereum.EventParam("newOwner", ethereum.Value.fromAddress(newOwner))
  )

  return ownershipTransferredEvent
}

export function createSetAutomatedMarketMakerPairEvent(
  pair: Address,
  value: boolean
): SetAutomatedMarketMakerPair {
  let setAutomatedMarketMakerPairEvent = changetype<
    SetAutomatedMarketMakerPair
  >(newMockEvent())

  setAutomatedMarketMakerPairEvent.parameters = new Array()

  setAutomatedMarketMakerPairEvent.parameters.push(
    new ethereum.EventParam("pair", ethereum.Value.fromAddress(pair))
  )
  setAutomatedMarketMakerPairEvent.parameters.push(
    new ethereum.EventParam("value", ethereum.Value.fromBoolean(value))
  )

  return setAutomatedMarketMakerPairEvent
}

export function createTransferEvent(
  from: Address,
  to: Address,
  value: BigInt
): Transfer {
  let transferEvent = changetype<Transfer>(newMockEvent())

  transferEvent.parameters = new Array()

  transferEvent.parameters.push(
    new ethereum.EventParam("from", ethereum.Value.fromAddress(from))
  )
  transferEvent.parameters.push(
    new ethereum.EventParam("to", ethereum.Value.fromAddress(to))
  )
  transferEvent.parameters.push(
    new ethereum.EventParam("value", ethereum.Value.fromUnsignedBigInt(value))
  )

  return transferEvent
}

export function createUpdatedBuyingFeesEvent(
  newLiquidityBuyingFee: BigInt,
  newTreasuryBuyingFee: BigInt,
  newBurnBuyingFee: BigInt
): UpdatedBuyingFees {
  let updatedBuyingFeesEvent = changetype<UpdatedBuyingFees>(newMockEvent())

  updatedBuyingFeesEvent.parameters = new Array()

  updatedBuyingFeesEvent.parameters.push(
    new ethereum.EventParam(
      "newLiquidityBuyingFee",
      ethereum.Value.fromUnsignedBigInt(newLiquidityBuyingFee)
    )
  )
  updatedBuyingFeesEvent.parameters.push(
    new ethereum.EventParam(
      "newTreasuryBuyingFee",
      ethereum.Value.fromUnsignedBigInt(newTreasuryBuyingFee)
    )
  )
  updatedBuyingFeesEvent.parameters.push(
    new ethereum.EventParam(
      "newBurnBuyingFee",
      ethereum.Value.fromUnsignedBigInt(newBurnBuyingFee)
    )
  )

  return updatedBuyingFeesEvent
}

export function createUpdatedLiquidityWalletEvent(
  newLiquidityWallet: Address,
  oldLiquidityWallet: Address
): UpdatedLiquidityWallet {
  let updatedLiquidityWalletEvent = changetype<UpdatedLiquidityWallet>(
    newMockEvent()
  )

  updatedLiquidityWalletEvent.parameters = new Array()

  updatedLiquidityWalletEvent.parameters.push(
    new ethereum.EventParam(
      "newLiquidityWallet",
      ethereum.Value.fromAddress(newLiquidityWallet)
    )
  )
  updatedLiquidityWalletEvent.parameters.push(
    new ethereum.EventParam(
      "oldLiquidityWallet",
      ethereum.Value.fromAddress(oldLiquidityWallet)
    )
  )

  return updatedLiquidityWalletEvent
}

export function createUpdatedPancakeRouterEvent(
  newAddress: Address,
  oldAddress: Address
): UpdatedPancakeRouter {
  let updatedPancakeRouterEvent = changetype<UpdatedPancakeRouter>(
    newMockEvent()
  )

  updatedPancakeRouterEvent.parameters = new Array()

  updatedPancakeRouterEvent.parameters.push(
    new ethereum.EventParam(
      "newAddress",
      ethereum.Value.fromAddress(newAddress)
    )
  )
  updatedPancakeRouterEvent.parameters.push(
    new ethereum.EventParam(
      "oldAddress",
      ethereum.Value.fromAddress(oldAddress)
    )
  )

  return updatedPancakeRouterEvent
}

export function createUpdatedRewardWalletEvent(
  newRewardWallet: Address,
  oldRewardWallet: Address
): UpdatedRewardWallet {
  let updatedRewardWalletEvent = changetype<UpdatedRewardWallet>(newMockEvent())

  updatedRewardWalletEvent.parameters = new Array()

  updatedRewardWalletEvent.parameters.push(
    new ethereum.EventParam(
      "newRewardWallet",
      ethereum.Value.fromAddress(newRewardWallet)
    )
  )
  updatedRewardWalletEvent.parameters.push(
    new ethereum.EventParam(
      "oldRewardWallet",
      ethereum.Value.fromAddress(oldRewardWallet)
    )
  )

  return updatedRewardWalletEvent
}

export function createUpdatedSellingFeesEvent(
  newLiquiditySellingFee: BigInt,
  newTreasurySellingFee: BigInt,
  newBurnSellingFee: BigInt
): UpdatedSellingFees {
  let updatedSellingFeesEvent = changetype<UpdatedSellingFees>(newMockEvent())

  updatedSellingFeesEvent.parameters = new Array()

  updatedSellingFeesEvent.parameters.push(
    new ethereum.EventParam(
      "newLiquiditySellingFee",
      ethereum.Value.fromUnsignedBigInt(newLiquiditySellingFee)
    )
  )
  updatedSellingFeesEvent.parameters.push(
    new ethereum.EventParam(
      "newTreasurySellingFee",
      ethereum.Value.fromUnsignedBigInt(newTreasurySellingFee)
    )
  )
  updatedSellingFeesEvent.parameters.push(
    new ethereum.EventParam(
      "newBurnSellingFee",
      ethereum.Value.fromUnsignedBigInt(newBurnSellingFee)
    )
  )

  return updatedSellingFeesEvent
}

export function createUpdatedTreasuryWalletEvent(
  newTreasuryWallet: Address,
  oldTreasuryWallet: Address
): UpdatedTreasuryWallet {
  let updatedTreasuryWalletEvent = changetype<UpdatedTreasuryWallet>(
    newMockEvent()
  )

  updatedTreasuryWalletEvent.parameters = new Array()

  updatedTreasuryWalletEvent.parameters.push(
    new ethereum.EventParam(
      "newTreasuryWallet",
      ethereum.Value.fromAddress(newTreasuryWallet)
    )
  )
  updatedTreasuryWalletEvent.parameters.push(
    new ethereum.EventParam(
      "oldTreasuryWallet",
      ethereum.Value.fromAddress(oldTreasuryWallet)
    )
  )

  return updatedTreasuryWalletEvent
}
