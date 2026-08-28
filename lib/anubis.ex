defmodule Anubis do
  @moduledoc false

  import Peri

  alias Anubis.Server.Transport.SSE, as: ServerSSE
  alias Anubis.Server.Transport.STDIO, as: ServerSTDIO
  alias Anubis.Server.Transport.StreamableHTTP, as: ServerStreamableHTTP
  alias Anubis.Transport.SSE, as: ClientSSE
  alias Anubis.Transport.STDIO, as: ClientSTDIO
  alias Anubis.Transport.StreamableHTTP, as: ClientStreamableHTTP

  @client_transports if Mix.env() == :test,
                       do: [
                         ClientSTDIO,
                         ClientSSE,
                         ClientStreamableHTTP,
                         StubTransport,
                         Anubis.MockTransport
                       ],
                       else: [ClientSTDIO, ClientSSE, ClientStreamableHTTP]

  @server_transports if Mix.env() == :test,
                       do: [
                         ServerSTDIO,
                         ServerStreamableHTTP,
                         ServerSSE,
                         StubTransport
                       ],
                       else: [ServerSTDIO, ServerStreamableHTTP, ServerSSE]

  defschema :client_transport,
    layer: {:required, {:enum, @client_transports}},
    name: {:required, get_schema(:process_name)}

  defschema :server_transport,
    layer: {:required, {:enum, @server_transports}},
    name: {:required, get_schema(:process_name)}

  defschema :process_name, {:either, {:pid, {:custom, &genserver_name/1}}}

  @doc "Checks if anubis should be compiled/used as standalone CLI or OTP library"
  def should_compile_cli? do
    Code.ensure_loaded?(Burrito) and
      Application.get_env(:anubis_mcp, :compile_cli?, false)
  end

  @doc """
  Validates a possible GenServer name using `peri` `:custom` type definition.
  """
  def genserver_name({:via, registry, _}) when is_atom(registry), do: :ok
  def genserver_name({:global, _}), do: :ok
  def genserver_name(name) when is_atom(name), do: :ok

  def genserver_name(val) do
    {:error, "#{inspect(val, pretty: true)} is not a valid name for a GenServer"}
  end

  @doc false
  def exported?(m, f, a) do
    function_exported?(m, f, a) or
      (Code.ensure_loaded?(m) and function_exported?(m, f, a))
  end

  @spec get_session_store_adapter :: nil | module
  def get_session_store_adapter do
    config = Application.get_env(:anubis_mcp, :session_store)
    enabled? = config[:enabled] || false
    adapter = config[:adapter]

    if enabled? && Code.ensure_loaded?(adapter), do: adapter
  end

  # A literal, not `to_timeout/1`: that is 1.17+ and this fork targets ~> 1.16.
  # Styler rewrites `:timer.minutes/1` into `to_timeout/1`, so keep it a literal
  # (same convention as @default_session_idle_timeout). 30 minutes in ms.
  @default_session_store_ttl 1_800_000

  @spec get_session_store_ttl :: pos_integer
  def get_session_store_ttl do
    config = Application.get_env(:anubis_mcp, :session_store) || []
    config[:ttl] || @default_session_store_ttl
  end
end
