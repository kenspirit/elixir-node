defmodule Aecore.Contract.Call do
  @moduledoc """
  Aecore call module implementation.
  """
  alias Aecore.Chain.Identifier
  alias Aecore.Contract.Call
  alias Aeutil.Serialization
  alias Aeutil.Parser
  alias Aeutil.Hash

  @version 1

  @type t :: %Call{
          caller_address: Wallet.pubkey(),
          caller_nonce: integer(),
          height: integer(),
          contract_address: Wallet.pubkey(),
          gas_price: non_neg_integer(),
          gas_used: non_neg_integer(),
          return_value: binary(),
          return_type: :ok | :error | :revert
        }

  @type hash :: binary()

  defstruct [
    :caller_address,
    :caller_nonce,
    :height,
    :contract_address,
    :gas_price,
    :gas_used,
    :return_value,
    :return_type
  ]

  @nonce_size 256

  @spec new(hash(), non_neg_integer(), hash(), non_neg_integer(), non_neg_integer()) :: t()
  def new(caller_address, nonce, block_height, contract_address, gas_price) do
    identified_caller_address = Identifier.create_identity(caller_address, :account)
    identified_contract_address = Identifier.create_identity(contract_address, :contract)

    %Call{
      :caller_address => identified_caller_address,
      :caller_nonce => nonce,
      :height => block_height,
      :contract_address => identified_contract_address,
      :gas_price => gas_price,
      :gas_used => 0,
      :return_value => <<>>,
      :return_type => :ok
    }
  end

  @spec encode_to_list(Call.t()) :: list()
  def encode_to_list(%Call{} = call) do
    [
      @version,
      Identifier.encode_to_binary(call.caller_address),
      call.caller_nonce,
      call.height,
      Identifier.encode_to_binary(call.contract_address),
      call.gas_price,
      call.gas_used,
      call.return_value,
      Parser.to_string(call.return_type)
    ]
  end

  @spec decode_from_list(integer(), list()) :: {:ok, t()} | {:error, String.t()}
  def decode_from_list(@version, [
        encoded_caller_address,
        caller_nonce,
        height,
        encoded_contract_address,
        gas_price,
        gas_used,
        return_value,
        return_type
      ]) do
    {:ok, decoded_caller_address} = Identifier.decode_from_binary(encoded_caller_address)
    {:ok, decoded_contract_address} = Identifier.decode_from_binary(encoded_contract_address)

    {:ok,
     %Call{
       caller_address: decoded_caller_address,
       caller_nonce: Serialization.transform_item(caller_nonce, :int),
       height: Serialization.transform_item(height, :int),
       contract_address: decoded_contract_address,
       gas_price: Serialization.transform_item(gas_price, :int),
       gas_used: Serialization.transform_item(gas_used, :int),
       return_value: return_value,
       return_type: String.to_atom(return_type)
     }}
  end

  def decode_from_list(@version, data) do
    {:error, "#{__MODULE__}: decode_from_list: Invalid serialization: #{inspect(data)}"}
  end

  def decode_from_list(version, _) do
    {:error, "#{__MODULE__}: decode_from_list: Unknown version #{version}"}
  end

  @spec id(Call.t()) :: binary()
  def id(call), do: id(call.caller_address, call.caller_nonce, call.contract_address)

  @spec id(binary(), non_neg_integer(), binary()) :: binary()
  def id(caller, nonce, contract) do
    binary = <<caller.value::binary, nonce::size(@nonce_size), contract.value::binary>>

    Hash.hash(binary)
  end
end
