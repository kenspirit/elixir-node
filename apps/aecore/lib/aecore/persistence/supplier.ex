defmodule Aecore.Persistence.Supplier do
  @moduledoc """
  Simple module responsible for storing and getting references needed for RoxDB 
  """
  use GenServer

  @spec start_link(any()) :: :ignore | {:error, any()} | {:ok, pid()}
  def start_link(_arg) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @spec store_references(map()) :: {:error, String.t()} | :ok
  def store_references(%{db: _, families_map: _} = references) do
    GenServer.call(__MODULE__, {:store_references, references})
  end

  def store_references(_) do
    {:error, "#{__MODULE__}: Error, invalid database/references information given"}
  end

  @spec get_references() :: map()
  def get_references do
    GenServer.call(__MODULE__, :get_references)
  end

  def init(_) do
    {:ok, %{db: nil, families_map: nil}}
  end

  def handle_call({:store_references, %{db: db, families_map: families_map}}, _from, state) do
    {:reply, :ok, %{state | db: db, families_map: families_map}}
  end

  def handle_call(:get_references, _from, state) do
    {:reply, state, state}
  end
end
