defmodule Aecore.Channel.Tx.ChannelOpenTx do
  @moduledoc """
  Aecore structure of a transaction data.
  """

  @behaviour Aecore.Tx.Transaction
  alias Aecore.Channel.Tx.ChannelOpenTx
  alias Aecore.Tx.DataTx
  alias Aecore.Account.Account
  alias Aecore.Chain.ChainState
  alias Aecore.Channel.ChannelStateOnChain

  require Logger

  @typedoc "Expected structure for the ChannelOpen Transaction"
  @type payload :: %{
    initiator_amount: non_neg_integer(),
    responser_amount: non_neg_integer(),
    locktime: non_neg_integer()
  }

  @typedoc "Reason for the error"
  @type reason :: String.t()

  @typedoc "Structure that holds specific transaction info in the chainstate.
  In the case of SpendTx we don't have a subdomain chainstate."
  @type tx_type_state() :: %{}

  @typedoc "Structure of the ChannelOpen Transaction type"
  @type t :: %ChannelOpenTx{
    initiator_amount: non_neg_integer(),
    responder_amount: non_neg_integer(),
    locktime: non_neg_integer()
  }

  @doc """
  Definition of Aecore ChannelOpenTx structure

  ## Parameters
  - initiator_amount: amount that account first on the senders list commits
  - responser_amount: amount that account second on the senders list commits
  - locktime: number of blocks for dispute settling
  """
  defstruct [:initiator_amount, :responder_amount, :locktime]
  use ExConstructor

  @spec get_chain_state_name :: :channels
  def get_chain_state_name, do: :channels

  @spec init(payload()) :: SpendTx.t()
  def init(%{initiator_amount: initiator_amount, responder_amount: responder_amount, locktime: locktime} = _payload) do
    %ChannelOpenTx{initiator_amount: initiator_amount, responder_amount: responder_amount, locktime: locktime}
  end

  @doc """
  Checks transactions internal contents validity
  """
  @spec is_valid?(ChannelOpenTx.t(), DataTx.t()) :: boolean()
  def is_valid?(%ChannelOpenTx{} = tx, data_tx) do
    senders = DataTx.senders(data_tx)
    
    cond do
      tx.initiator_amount + tx.responder_amount < 0 ->
        Logger.error("Channel cannot have negative total balance")
        false

      tx.locktime < 0 ->
        Logger.error("Locktime cannot be negative")
        false

      length(senders) != 2 ->
        Logger.error("Invalid from_accs size")
        false

      true ->
        true
    end
  end

  @doc """
  Changes the account state (balance) of both parties and creates channel object
  """
  @spec process_chainstate!(
          ChainState.account(),
          ChannelStateOnChain.channels(),
          non_neg_integer(),
          ChannelOpenTx.t(),
          DataTx.t()) :: {ChainState.accounts(), ChannelStateOnChain.t()}
  def process_chainstate!(
    accounts,
    channels,
    _block_height,
    %ChannelOpenTx{} = tx,
    data_tx
  ) do
    [initiator_pubkey, responder_pubkey] = DataTx.senders(data_tx)
    nonce = DataTx.nonce(data_tx)

    new_accounts =
      accounts
      |> AccountStateTree.update(initiator_pubkey, fn acc ->
        Account.apply_transfer!(tx.initiator_amount * -1)
      end)
      |> AccountStateTree.update(responder_pubkey, fn acc ->
        Account.apply_transfer!(tx.responder_amount * -1)
      end)

    channel = ChannelStateOnChain.create(initiator_pubkey, responder_pubkey, tx.initiator_amount, tx.responder_amount, tx.lock_time)
    channel_id = get_id(initiator_pubkey, responder_pubkey, nonce)

    new_channels = Map.put(channels, channel_id, channel)

    {new_accounts, new_channels}
  end

  @doc """
  Checks whether all the data is valid according to the SpendTx requirements,
  before the transaction is executed.
  """
  @spec preprocess_check!(
          ChainState.account(),
          ChannelStateOnChain.channels(),
          non_neg_integer(),
          ChannelOpenTx.t(),
          DataTx.t()) 
  :: :ok
  def preprocess_check!(
    accounts,
    channels,
    _block_height,
    %ChannelOpenTx{} = tx,
    data_tx
  ) do
    [initiator_pubkey, responder_pubkey] = DataTx.senders(data_tx)
    nonce = DataTx.nonce(data_tx)
    fee = DataTx.fee(data_tx)

    cond do
      AccountStateTree.get(accounts, initiator_pubkey).balance - (fee + tx.initiator_amount) < 0 ->
        throw({:error, "Negative initiator balance"})

      AccountStateTree.get(accounts, responder_pubkey).balance - tx.responder_amount < 0 ->
        throw({:error, "Negative responder balance"})

      Map.has_key?(channels, get_id(initiator_pubkey, responder_pubkey, nonce)) ->
        throw({:error, "Channel already exists"})

      true ->
        :ok
    end
  end

  @spec deduct_fee(
          ChainState.accounts(),
          non_neg_integer(),
          ChannelOpenTx.t(),
          DataTx.t(),
          non_neg_integer()
        ) :: ChainState.account()
  def deduct_fee(accounts, block_height, _tx, data_tx, fee) do
    DataTx.standard_deduct_fee(accounts, block_height, data_tx, fee)
  end

  defp get_id(initiator_pubkey, responder_pubkey, nonce) do
    <<123>> #TODO implement
  end
end
