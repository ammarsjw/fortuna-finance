import { ethereum, log } from '@graphprotocol/graph-ts'
// schema imports
import { Transaction } from '../../generated/schema'

export function loadOrCreateTransaction(eth_transaction: ethereum.Transaction, eth_block: ethereum.Block): Transaction {
  log.debug('loadOrCreateTransaction {}', [eth_transaction.hash.toHex()])
  let transaction = Transaction.load(eth_transaction.hash.toHex())
  if (transaction == null) {
    transaction = new Transaction(eth_transaction.hash.toHex())
    transaction.timestamp = eth_block.timestamp
    transaction.blockNumber = eth_block.number
    transaction.blockHash = eth_block.hash
    transaction.from = eth_transaction.from
    transaction.to = eth_transaction.to
    transaction.value = eth_transaction.value
    transaction.gasPrice = eth_transaction.gasPrice
    transaction.save()
    log.debug('new transaction created {}', [eth_transaction.hash.toHex()])
  }
  
  return transaction as Transaction
}
