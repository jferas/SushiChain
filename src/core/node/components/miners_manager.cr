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

module ::Sushi::Core::NodeComponents
  class MinersManager < HandleSocket
    alias MinerContext = NamedTuple(
      address: String,
      nonces: Array(UInt64),
    )

    alias MinerContexts = Array(MinerContext)

    alias Miner = NamedTuple(
      context: MinerContext,
      socket: HTTP::WebSocket,
      mid: String
    )

    alias Miners = Array(Miner)

    getter miners : Miners = Miners.new

    def initialize(@blockchain : Blockchain)
    end

    def handshake(socket, _content)
      return unless node.phase == SetupPhase::DONE

      verbose "requested handshake from a miner"

      _m_content = MContentMinerHandshake.from_json(_content)

      version = _m_content.version
      address = _m_content.address
      mid = _m_content.mid

      if Core::CORE_VERSION > version
        return send(socket,
          M_TYPE_MINER_HANDSHAKE_REJECTED,
          {
            reason: "your sushim is out of date, please update it" +
                    "(node version: #{Core::CORE_VERSION}, miner version: #{version})",
          })
      end

      miner_network = Wallet.address_network_type(address)[:name]

      if miner_network != node.network_type
        warning "mismatch network type with miner #{address}"

        return send(socket, M_TYPE_MINER_HANDSHAKE_REJECTED, {
          reason: "network type mismatch",
        })
      end

      miner_context = {address: address, nonces: [] of UInt64}
      miner = {context: miner_context, socket: socket, mid: mid}

      @miners << miner

      miner_name = HumanHash.humanize(mid)
      info "new miner: #{light_green(miner_name)} (#{@miners.size})"

      send(socket, M_TYPE_MINER_HANDSHAKE_ACCEPTED, {
        version:    Core::CORE_VERSION,
        block:      @blockchain.mining_block,
        difficulty: @blockchain.mining_block_difficulty_miner,
      })
    end

    def found_nonce(socket, _content)
      return unless node.phase == SetupPhase::DONE

      verbose "miner sent a new nonce"

      _m_content = MContentMinerFoundNonce.from_json(_content)

      nonce = _m_content.nonce

      if miner = find?(socket)
        if @miners.map { |m| m[:context][:nonces] }.flatten.includes?(nonce)
          warning "nonce #{nonce} has already been discoverd"
        elsif !@blockchain.mining_block.with_nonce(nonce).valid_nonce?(@blockchain.mining_block_difficulty_miner)
          warning "received nonce is invalid, try to update latest block"

          send(miner[:socket], M_TYPE_MINER_BLOCK_UPDATE, {
            block:      @blockchain.mining_block,
            difficulty: @blockchain.mining_block_difficulty_miner
          })
        else
          miner_name = HumanHash.humanize(miner[:mid])
          debug "miner #{miner_name} found nonce (nonces: #{miner[:context][:nonces].size})"

          miner[:context][:nonces].push(nonce)

          if block = @blockchain.valid_nonce?(nonce)
            node.new_block(block)
            node.send_block(block)

            clear_nonces
          end
        end
      end
    end

    def clear_nonces
      @miners.each do |m|
        m[:context][:nonces].clear
      end
    end

    def broadcast
      info "#{magenta("UPDATED BLOCK")}: #{light_green(@blockchain.mining_block.index)} at difficulty: #{light_cyan(@blockchain.mining_block_difficulty)}"
      debug "new block difficulty: #{@blockchain.mining_block_difficulty}, " +
            "mining difficulty: #{@blockchain.mining_block_difficulty_miner}"

      @miners.each do |miner|
        send(miner[:socket], M_TYPE_MINER_BLOCK_UPDATE, {
          block:      @blockchain.mining_block,
          difficulty: @blockchain.mining_block_difficulty_miner
        })
      end
    end

    def find?(socket : HTTP::WebSocket) : Miner?
      @miners.find { |m| m[:socket] == socket }
    end

    def clean_connection(socket)
      current_size = @miners.size
      @miners.reject! { |miner| miner[:socket] == socket }

      info "a miner has been removed. (#{current_size} -> #{@miners.size})" if current_size > @miners.size
    end

    def size
      @miners.size
    end

    def miner_contexts : MinerContexts
      @miners.map { |m| m[:context] }
    end

    private def node
      @blockchain.node
    end

    include Protocol
    include Consensus
    include Common::Color
  end
end
