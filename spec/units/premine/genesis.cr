# Copyright © 2017-2018 The SushiChain Core developers
#
# See the LICENSE file at the top-level directory of this distribution
# for licensing information.
#
# Unless otherwise agreed in a custom licensing agreement with the SushiChain Core developers,
# no part of this software, including this file, may be copied, modified,
# propagated, or distributed except according to the terms contained in the
# LICENSE file.
#
# Removal or modification of this copyright notice is prohibited.

require "./../../spec_helper"
require "./../utils"

include Sushi::Core

describe Blockchain do
  it "should create a genesis block with no transactions when no premine is provided" do
    node_wallet = Wallet.from_json(Wallet.create(true).to_json)
    node = Sushi::Core::Node.new(true, true, "bind_host", 8008_i32, nil, nil, nil, nil, nil, node_wallet, nil, nil, false)
    blockchain = node.blockchain
    blockchain.setup(node)

    genesis_block = blockchain.chain.first
    genesis_block.prev_hash.should eq("genesis")
    genesis_block.transactions.should eq([] of Transaction)
  end

  it "should create a genesis block with the specified transactions when premine is provided" do
    node_wallet = Wallet.from_json(Wallet.create(true).to_json)
    premine = Premine.validate("#{__DIR__}/../utils/data/premine.yml")
    node = Sushi::Core::Node.new(true, true, "bind_host", 8008_i32, nil, nil, nil, nil, nil, node_wallet, nil, premine, false)
    blockchain = node.blockchain
    blockchain.setup(node)

    genesis_block = blockchain.chain.first
    genesis_block.prev_hash.should eq("genesis")
    expected_recipients = [{address: "VDA2NjU5N2JlNDA3ZDk5Nzg4MGY2NjY5YjhhOTUwZTE2M2VmNjM5OWM2M2EyMWQz", amount: 500000000000}, {address: "VDAyMzEwODI2NmE1MWJiYTAxOTA2YjE0NzRjYTRjYjllYTk0ZDZhYmJhZGU3MmIz", amount: 900000000000}]
    genesis_block.transactions.flat_map(&.recipients).sort_by(&.["amount"]).should eq(expected_recipients)
  end

    STDERR.puts "< Premine::Genesis"
end
