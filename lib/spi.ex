defmodule Spi do
  use GenServer

  @moduledoc """
  This module enables Elixir programs to interact with hardware that's connected
  via a SPI bus.
  """

  defmodule State do
    defstruct port: nil, devname: nil
  end

  # Public API
  @doc """
  Start and link a Spi GenServer.

  `devname` is the Linux device name for the bus (e.g., "spidev0.0")
  `bits_per_word` is the number of bits for each word sent to the bus (currently only 8 is supported)
  `speed_hz` is the bus speed
  `delay_us` is the delay in microseconds between transactions
  """
  def start_link(devname, mode \\ 0, bits_per_word \\ 8, speed_hz \\ 1000000, delay_us \\ 10) do
    GenServer.start_link(__MODULE__, [devname, mode, bits_per_word, speed_hz, delay_us])
  end

  @doc """
  Stop the GenServer and release the SPI resources.
  """
  def release(pid) do
    GenServer.cast pid, :release
  end

  @doc """
  Perform a SPI transfer. The `data` should be a binary containing the bytes to
  send. Since SPI transfers simultaneously send and receive, the return value will
  be a binary of the same length.
  """
  def transfer(pid, data) do
    GenServer.call pid, {:transfer, data}
  end

  # gen_server callbacks
  def init([devname, mode, bits_per_word, speed_hz, delay_us]) do
    executable = :code.priv_dir(:elixir_ale) ++ '/ale'
    port = Port.open({:spawn_executable, executable},
      [{:args, ["spi",
                "/dev/#{devname}",
                Integer.to_string(mode),
                Integer.to_string(bits_per_word),
                Integer.to_string(speed_hz),
                Integer.to_string(delay_us)]},
       {:packet, 2},
       :use_stdio,
       :binary,
       :exit_status])
    state = %State{port: port, devname: devname}
    {:ok, state}
  end

  def handle_call({:transfer, data}, _from, state) do
    {:ok, response} = call_port(state, :transfer, data)
    {:reply, response, state}
  end

  def handle_cast(:release, state) do
    {:stop, :normal, state}
  end

  # Private helper functions
  defp call_port(state, command, arguments) do
    msg = {command, arguments}
    send state.port, {self, {:command, :erlang.term_to_binary(msg)}}
    receive do
      {_, {:data, response}} ->
        {:ok, :erlang.binary_to_term(response)}
        _ -> :error
    end
  end
end
